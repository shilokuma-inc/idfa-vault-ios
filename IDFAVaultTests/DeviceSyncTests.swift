//
//  DeviceSyncTests.swift
//  IDFAVaultTests
//
//  iCloud の同期（仕様書 3.4・3.5・5 章）。CloudKit は偽物（StubDeviceSync）に差し替えて確かめる。
//

import CloudKit
import Foundation
@testable import IDFAVault
import Testing

struct DeviceSyncTests {
    private static let identifier = UITesting.sampleIdentifier
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeModel(
        sync: StubDeviceSync,
        tracking: StubTrackingProvider = StubTrackingProvider(status: .authorized, identifier: identifier)
    ) -> AppModel {
        AppModel(dependencies: AppDependencies(
            authenticator: StubAuthenticator(kind: .faceID, outcome: .success),
            tracking: tracking,
            clipboard: NoopClipboard(),
            deviceInfo: StubDeviceInfo(deviceID: "this-device", platform: .iOS, name: "iPhone 16 Pro"),
            sync: sync,
            defaults: .volatile(named: "tests.\(UUID().uuidString)"),
            trackingPromptDelay: .zero,
            syncRefreshInterval: .seconds(3_600)
        ))
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<200 where !condition() {
            await Task.yield()
        }
    }

    // MARK: - 書き込み

    /// ロックを解除したら、この端末のレコードを書いて、他の端末を最終更新の新しい順に出す
    @Test
    func uploadsOwnRecordAndListsOtherDevicesNewestFirst() async {
        let sync = StubDeviceSync(records: StubDeviceSync.demoDevices(now: Self.now))
        let model = makeModel(sync: sync)

        await model.unlock()
        await waitUntil { model.devices.status == .synced }

        let own = sync.records["this-device"]
        #expect(own?.name == "iPhone 16 Pro")
        #expect(own?.platform == .iOS)
        #expect(own?.identifier == Self.identifier)
        #expect(own?.trackingStatus == .authorized)
        #expect(
            model.devices.otherDevices.map(\.id) == ["demo-ipad", "demo-iphone-15", "demo-iphone", "demo-ipad-mini"],
            "自分の端末は一覧に出さない"
        )
        #expect(model.devices.lastSyncedAt != nil)
    }

    /// 未許可の端末は IDFA を空で書く（全桁 0 は同期しない）
    @Test
    func uploadsNoIdentifierWhenTrackingIsDenied() async {
        let sync = StubDeviceSync()
        let model = makeModel(sync: sync, tracking: StubTrackingProvider(status: .denied, identifier: Self.identifier))

        await model.unlock()
        await waitUntil { sync.records["this-device"] != nil }

        #expect(sync.records["this-device"]?.identifier == nil)
        #expect(sync.records["this-device"]?.trackingStatus == .denied)
    }

    /// 許可のダイアログで許可されたら、IDFA を入れて書き直す
    @Test
    func rewritesOwnRecordAfterTrackingIsAllowed() async {
        let sync = StubDeviceSync()
        let tracking = StubTrackingProvider(status: .notDetermined, identifier: Self.identifier, requestResult: .authorized)
        let model = makeModel(sync: sync, tracking: tracking)

        await model.unlock()
        await waitUntil { sync.records["this-device"]?.trackingStatus == .authorized }

        #expect(sync.records["this-device"]?.identifier == Self.identifier)
    }

    /// 「このデバイスの IDFA を同期」をオフにしたら、自分のレコードを消し、以降は書かない（仕様書 3.5）
    @Test
    func turningOffSyncDeletesOwnRecord() async {
        let sync = StubDeviceSync()
        let model = makeModel(sync: sync)
        await model.unlock()
        await waitUntil { sync.records["this-device"] != nil }

        await model.setSyncsThisDevice(false)

        #expect(sync.records["this-device"] == nil)
        #expect(!model.settings.syncsThisDevice)
        let saves = sync.saveCount
        await model.refreshDevices()
        #expect(sync.saveCount == saves)
    }

    /// 「iCloud の同期データをすべて削除」で、すべての端末が一覧から消える
    @Test
    func deleteAllRemovesEveryDevice() async {
        let sync = StubDeviceSync(records: StubDeviceSync.demoDevices(now: Self.now))
        let model = makeModel(sync: sync)
        await model.unlock()
        await waitUntil { model.devices.status == .synced }

        let deleted = await model.deleteAllSyncedData()

        #expect(deleted)
        #expect(sync.records.isEmpty)
        #expect(model.devices.otherDevices.isEmpty)
    }

    // MARK: - 状態

    @Test
    func showsNoAccountWhenSignedOutOfICloud() async {
        let model = makeModel(sync: StubDeviceSync(availability: .noAccount))

        await model.unlock()
        await waitUntil { model.devices.status != .idle }

        #expect(model.devices.status == .noAccount)
        #expect(model.devices.otherDevices.isEmpty)
    }

    /// Mac・visionOS は IDFA を取れないので、前の版が書いたレコードが残っていても一覧に出さない
    @Test
    func hidesDevicesThatCannotProvideAnIdentifier() async {
        let mac = DeviceRecord(
            id: "old-mac",
            name: "MacBook Pro",
            platform: .macOS,
            identifier: nil,
            trackingStatus: .notDetermined,
            updatedAt: Self.now
        )
        let vision = DeviceRecord(
            id: "old-vision",
            name: "Apple Vision Pro",
            platform: .visionOS,
            identifier: nil,
            trackingStatus: .notDetermined,
            updatedAt: Self.now
        )
        let sync = StubDeviceSync(records: StubDeviceSync.demoDevices(now: Self.now) + [mac, vision])
        let model = makeModel(sync: sync)

        await model.unlock()
        await waitUntil { model.devices.status == .synced }

        #expect(model.devices.otherDevices.allSatisfy { $0.platform == .iOS || $0.platform == .iPadOS })
        #expect(model.devices.otherDevices.count == 4)
    }

    /// 自分の IDFA を取れない端末（Mac・visionOS）は、許可を求めず、自分のレコードも書かずに一覧だけ読む
    @Test
    func listsOnlyWhereTheIdentifierIsUnavailable() async {
        let sync = StubDeviceSync(records: StubDeviceSync.demoDevices(now: Self.now))
        let tracking = StubTrackingProvider(status: .notDetermined, supportsAdvertisingIdentifier: false)
        let model = makeModel(sync: sync, tracking: tracking)

        await model.unlock()
        await waitUntil { model.devices.status == .synced }

        #expect(tracking.requestCount == 0)
        #expect(sync.records["this-device"] == nil)
        #expect(model.ownIdentifier == nil)
        #expect(model.devices.otherDevices.count == 4)
    }

    /// 通信に失敗しても、前に読めた一覧は残す
    @Test
    func keepsTheLastListWhenARefreshFails() async {
        let sync = StubDeviceSync(records: StubDeviceSync.demoDevices(now: Self.now))
        let model = makeModel(sync: sync)
        await model.unlock()
        await waitUntil { model.devices.status == .synced }

        sync.failsNextRequest = true
        await model.refreshDevices()

        #expect(model.devices.status == .failed)
        #expect(model.devices.otherDevices.count == 4)
    }

    // MARK: - 伏せ字

    /// 他の端末の IDFA は伏せ字で、タップで全桁と切り替える。ロックしたら伏せ字に戻す
    @Test
    func revealTogglesAndResetsOnLock() async throws {
        let sync = StubDeviceSync(records: StubDeviceSync.demoDevices(now: Self.now))
        let model = makeModel(sync: sync)
        await model.unlock()
        await waitUntil { model.devices.status == .synced }
        let device = try #require(model.devices.otherDevices.first)
        #expect(model.settings.masksOtherDevices)
        #expect(!model.devices.isRevealed(device))

        model.devices.toggleReveal(device)
        #expect(model.devices.isRevealed(device))

        model.lockNow()
        #expect(!model.devices.isRevealed(device))
    }

    // MARK: - CloudKit のレコード

    @Test
    func cloudKitRecordRoundTrip() throws {
        let record = DeviceRecord(
            id: "7F1D2C3B-0000-4000-8000-000000000001",
            name: "iPad Pro",
            platform: .iPadOS,
            identifier: Self.identifier,
            trackingStatus: .authorized,
            updatedAt: Self.now
        )

        let ckRecord = CloudKitDeviceSync.makeRecord(record)

        #expect(ckRecord.recordType == "DeviceIDFA")
        #expect(ckRecord.recordID.recordName == record.id)
        #expect(ckRecord["idfa"] as? String == "6D92078A-8246-4BA4-AE5B-76104861E7DC")
        #expect(ckRecord["platform"] as? String == "iPadOS")
        #expect(ckRecord["attStatus"] as? String == "authorized")
        #expect(try #require(CloudKitDeviceSync.makeDeviceRecord(ckRecord)) == record)
    }

    @Test
    func cloudKitRecordWithoutIdentifierIsEmpty() throws {
        let record = DeviceRecord(
            id: "a",
            name: "iPad mini",
            platform: .iPadOS,
            identifier: nil,
            trackingStatus: .denied,
            updatedAt: Self.now
        )

        let ckRecord = CloudKitDeviceSync.makeRecord(record)

        #expect((ckRecord["idfa"] as? String)?.isEmpty == true)
        #expect(try #require(CloudKitDeviceSync.makeDeviceRecord(ckRecord)).identifier == nil)
    }

    // MARK: - 端末名

    @Test
    func modelNamesFromIdentifiers() {
        #expect(DeviceModelName.name(for: "iPhone17,1", fallback: "iPhone") == "iPhone 16 Pro")
        #expect(DeviceModelName.name(for: "iPhone14,6", fallback: "iPhone") == "iPhone SE")
        #expect(DeviceModelName.name(for: "iPad16,5", fallback: "iPad") == "iPad Pro")
        #expect(DeviceModelName.name(for: "iPad14,1", fallback: "iPad") == "iPad mini")
        #expect(DeviceModelName.name(for: "iPhone99,9", fallback: "iPhone") == "iPhone", "知らないモデルは種類だけにする")
    }
}
