//
//  DeviceSyncModel.swift
//  IDFAVault
//
//  同じ Apple ID の他の端末の一覧（仕様書 3.4）。並び順は最終更新の新しい順。
//  他の端末の IDFA は、設定で伏せ字にしているときは伏せ、タップした端末だけ全桁を出す。
//

import Foundation
import Observation

@Observable
final class DeviceSyncModel {
    enum Status: Equatable {
        /// まだ一度も同期していない
        case idle
        case synced
        /// iCloud にサインインしていない
        case noAccount
        /// iCloud が使えない（制限・一時的な不調）か、通信に失敗した
        case failed
    }

    private(set) var status: Status = .idle
    /// この端末を除いた、同じ Apple ID の端末（最終更新の新しい順）
    private(set) var otherDevices: [DeviceRecord] = []
    /// 最後に同期できた時刻
    private(set) var lastSyncedAt: Date?
    /// 同期の途中か
    private(set) var isSyncing = false
    /// 全桁を出している端末（伏せ字にしているときに、タップした端末）
    private(set) var revealedDeviceIDs: Set<String> = []

    @ObservationIgnored private let service: any DeviceSyncing
    @ObservationIgnored private let ownDeviceID: String
    @ObservationIgnored private let now: () -> Date
    /// 同期の途中に頼まれた、この端末のレコードの書き込み。終わったあとに続けて書く
    @ObservationIgnored private var pendingUpload: DeviceRecord?
    @ObservationIgnored private var needsAnotherRefresh = false

    init(service: any DeviceSyncing, ownDeviceID: String, now: @escaping () -> Date = Date.init) {
        self.service = service
        self.ownDeviceID = ownDeviceID
        self.now = now
    }

    // MARK: - 同期

    /// 他の端末のレコードを読み直す。own を渡したら、先にこの端末のレコードを書く
    func refresh(uploading own: DeviceRecord? = nil) async {
        if let own {
            pendingUpload = own
        }
        guard !isSyncing else {
            needsAnotherRefresh = true
            return
        }
        isSyncing = true
        defer { isSyncing = false }
        repeat {
            needsAnotherRefresh = false
            let upload = pendingUpload
            pendingUpload = nil
            await performRefresh(uploading: upload)
        } while needsAnotherRefresh || pendingUpload != nil
    }

    private func performRefresh(uploading own: DeviceRecord?) async {
        switch await service.availability() {
        case .available:
            break
        case .noAccount:
            status = .noAccount
            otherDevices = []
            return
        case .unavailable:
            status = .failed
            return
        }
        do {
            if let own {
                try await service.save(own)
            }
            let records = try await service.fetchAll()
            // Mac・visionOS は IDFA を取れないので、前の版が書いたレコードが残っていても出さない
            otherDevices = records
                .filter { $0.id != ownDeviceID && $0.platform.providesAdvertisingIdentifier }
                .sorted { $0.updatedAt > $1.updatedAt }
            lastSyncedAt = now()
            status = .synced
        } catch {
            status = .failed
        }
    }

    /// この端末のレコードを消す（「このデバイスの IDFA を同期」をオフにしたとき）
    func deleteOwnRecord() async {
        pendingUpload = nil
        try? await service.delete(deviceID: ownDeviceID)
    }

    /// 同じ Apple ID のすべての端末のレコードを消す（「iCloud の同期データをすべて削除」）
    func deleteAll() async -> Bool {
        pendingUpload = nil
        do {
            try await service.deleteAll()
            otherDevices = []
            lastSyncedAt = now()
            status = .synced
            return true
        } catch {
            return false
        }
    }

    // MARK: - 伏せ字

    func isRevealed(_ device: DeviceRecord) -> Bool {
        revealedDeviceIDs.contains(device.id)
    }

    /// タップで全桁と伏せ字を切り替える
    func toggleReveal(_ device: DeviceRecord) {
        if revealedDeviceIDs.contains(device.id) {
            revealedDeviceIDs.remove(device.id)
        } else {
            revealedDeviceIDs.insert(device.id)
        }
    }

    /// ロックしたら、全桁を出していた端末も伏せ字に戻す
    func concealAll() {
        revealedDeviceIDs = []
    }
}
