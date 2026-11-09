//
//  DeviceSyncService.swift
//  IDFAVault
//
//  CloudKit のプライベートデータベースへの読み書き（仕様書 3.4・5 章）。パブリック DB とシェア DB は使わない。
//  レコードは専用のゾーン（Devices）に置く。ゾーンの変更の取得はクエリと違ってインデックスが要らず、
//  ゾーンを消せば自分の Apple ID のレコードをまとめて消せる。
//

import CloudKit

/// iCloud が使えるか
enum SyncAvailability: Equatable, Sendable {
    case available
    /// iCloud にサインインしていない
    case noAccount
    /// 制限されている（スクリーンタイム・構成プロファイルなど）か、一時的に使えない
    case unavailable
}

/// 端末のレコードを読み書きするもの。テストと撮影では偽物に差し替える
protocol DeviceSyncing {
    func availability() async -> SyncAvailability
    /// この端末のレコードを書く（上書き）
    func save(_ record: DeviceRecord) async throws
    /// この端末のレコードを消す
    func delete(deviceID: String) async throws
    /// 同じ Apple ID のすべての端末のレコード
    func fetchAll() async throws -> [DeviceRecord]
    /// 同じ Apple ID のすべての端末のレコードを消す
    func deleteAll() async throws
}

final class CloudKitDeviceSync: DeviceSyncing {
    static let recordType = "DeviceIDFA"
    private static let zoneID = CKRecordZone.ID(zoneName: "Devices", ownerName: CKCurrentUserDefaultName)

    private enum Field {
        static let deviceID = "deviceID"
        static let deviceName = "deviceName"
        static let platform = "platform"
        static let idfa = "idfa"
        static let attStatus = "attStatus"
        static let updatedAt = "updatedAt"
    }

    // CKContainer は iCloud の entitlement が無いと作った時点で止まるので、使うときまで作らない
    private lazy var container = CKContainer.default()
    private var database: CKDatabase { container.privateCloudDatabase }
    private var hasZone = false

    func availability() async -> SyncAvailability {
        switch try? await container.accountStatus() {
        case .available:
            .available
        case .noAccount:
            .noAccount
        default:
            .unavailable
        }
    }

    func save(_ record: DeviceRecord) async throws {
        try await ensureZone()
        let ckRecord = Self.makeRecord(record)
        do {
            _ = try await database.modifyRecords(saving: [ckRecord], deleting: [], savePolicy: .allKeys)
        } catch let error as CKError where error.code == .zoneNotFound {
            // ほかの端末が「すべて削除」でゾーンを消したあと。作り直して書き直す
            hasZone = false
            try await ensureZone()
            _ = try await database.modifyRecords(saving: [ckRecord], deleting: [], savePolicy: .allKeys)
        }
    }

    func delete(deviceID: String) async throws {
        do {
            _ = try await database.modifyRecords(saving: [], deleting: [CKRecord.ID(recordName: deviceID, zoneID: Self.zoneID)])
        } catch let error as CKError where [.zoneNotFound, .unknownItem].contains(error.code) {
            // 消すものが無い
        }
    }

    func fetchAll() async throws -> [DeviceRecord] {
        var records: [DeviceRecord] = []
        var token: CKServerChangeToken?
        do {
            while true {
                let changes = try await database.recordZoneChanges(inZoneWith: Self.zoneID, since: token)
                for (_, result) in changes.modificationResultsByID {
                    if case .success(let modification) = result, let record = Self.makeDeviceRecord(modification.record) {
                        records.append(record)
                    }
                }
                token = changes.changeToken
                if !changes.moreComing {
                    break
                }
            }
        } catch let error as CKError where error.code == .zoneNotFound {
            // まだどの端末も書いていない・すべて削除された
            hasZone = false
            return []
        }
        return records
    }

    func deleteAll() async throws {
        do {
            _ = try await database.modifyRecordZones(saving: [], deleting: [Self.zoneID])
        } catch let error as CKError where error.code == .zoneNotFound {
            // 消すものが無い
        }
        hasZone = false
    }

    private func ensureZone() async throws {
        guard !hasZone else {
            return
        }
        _ = try await database.modifyRecordZones(saving: [CKRecordZone(zoneID: Self.zoneID)], deleting: [])
        hasZone = true
    }

    // MARK: - レコードの変換

    static func makeRecord(_ record: DeviceRecord) -> CKRecord {
        let ckRecord = CKRecord(recordType: recordType, recordID: CKRecord.ID(recordName: record.id, zoneID: zoneID))
        ckRecord[Field.deviceID] = record.id
        ckRecord[Field.deviceName] = record.name
        ckRecord[Field.platform] = record.platform.rawValue
        // 許可されていない端末は空にする（全桁 0 は同期しない）
        ckRecord[Field.idfa] = record.identifier?.value ?? ""
        ckRecord[Field.attStatus] = record.trackingStatus.rawValue
        ckRecord[Field.updatedAt] = record.updatedAt
        return ckRecord
    }

    static func makeDeviceRecord(_ ckRecord: CKRecord) -> DeviceRecord? {
        guard ckRecord.recordType == recordType,
              let deviceID = ckRecord[Field.deviceID] as? String,
              let updatedAt = ckRecord[Field.updatedAt] as? Date else {
            return nil
        }
        let identifier = (ckRecord[Field.idfa] as? String).flatMap(AdvertisingIdentifier.init)
        return DeviceRecord(
            id: deviceID,
            name: ckRecord[Field.deviceName] as? String ?? "",
            platform: (ckRecord[Field.platform] as? String).flatMap(DevicePlatform.init(rawValue:)) ?? .iOS,
            identifier: identifier.flatMap { $0.isZero ? nil : $0 },
            trackingStatus: (ckRecord[Field.attStatus] as? String).flatMap(TrackingStatus.init(rawValue:)) ?? .notDetermined,
            updatedAt: updatedAt
        )
    }
}
