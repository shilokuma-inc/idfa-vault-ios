//
//  AppModel.swift
//  IDFAVault
//
//  アプリ全体の状態。ロック（仕様書 3.1）・トラッキングの許可と IDFA（3.2）・コピー（3.3）・iCloud の同期（3.4）を受け持つ。
//  ロックはすべてのウインドウに共通で、どのウインドウでも解除したら全体が解除される。
//

import Observation
import SwiftUI

@Observable
final class AppModel {
    /// コピーした IDFA をクリップボードに残す秒数（仕様書 3.3）
    static let clipboardLifetime: TimeInterval = 60

    let settings: AppSettings
    /// 同じ Apple ID の他の端末
    let devices: DeviceSyncModel

    /// ロック中か。起動したときはロックしている
    private(set) var isLocked: Bool
    /// 本人確認の途中か
    private(set) var isAuthenticating = false
    /// 最後の本人確認の結果。ロック画面の補足に使う（ロックし直したら消す）
    private(set) var lastAuthenticationOutcome: AuthenticationOutcome?
    /// 端末の生体認証の種類
    private(set) var biometry: BiometryKind
    /// このプラットフォームでアプリが IDFA を取得できるか（visionOS はできない）
    let supportsOwnIdentifier: Bool
    /// トラッキングの許可状態
    private(set) var trackingStatus: TrackingStatus
    /// この端末の IDFA。許可されていない・全桁 0 のときは nil
    private(set) var ownIdentifier: AdvertisingIdentifier?
    /// アプリが前面で操作できる状態か（scenePhase が active）
    private(set) var isInForeground = true
    /// 画面収録・ミラーリング中か（iOS・visionOS の sceneCaptureState）
    var isCapturingScreen = false
    /// コピーした回数。触覚フィードバックと「コピーしました」の表示のきっかけに使う
    private(set) var copyCount = 0
    /// この端末の表示名（iOS はモデル名、Mac はコンピュータ名）。読み終わるまでは nil
    private(set) var ownDeviceName: String?

    @ObservationIgnored private let authenticator: any Authenticating
    @ObservationIgnored private let tracking: any TrackingProviding
    @ObservationIgnored private let clipboard: any ClipboardWriting
    @ObservationIgnored private let trackingPromptDelay: Duration
    @ObservationIgnored private let deviceInfo: any DeviceInfoProviding
    @ObservationIgnored private let syncRefreshInterval: Duration
    /// 前面でロックを解除しているあいだ、他の端末の一覧を読み直し続けるタスク
    @ObservationIgnored private var refreshLoop: Task<Void, Never>?
    /// バックグラウンドに移った時刻。戻ったときに自動ロックの時間を過ぎたかを見る
    @ObservationIgnored private var backgroundedAt: Date?
    /// 前面に戻ったときに自動で本人確認を始めないか。取り消された・失敗したあとに、繰り返しダイアログを出さないため
    @ObservationIgnored private var suppressesAutomaticUnlock = false
    @ObservationIgnored private var isRequestingTracking = false

    init(dependencies: AppDependencies) {
        settings = AppSettings(defaults: dependencies.defaults)
        authenticator = dependencies.authenticator
        tracking = dependencies.tracking
        clipboard = dependencies.clipboard
        trackingPromptDelay = dependencies.trackingPromptDelay
        deviceInfo = dependencies.deviceInfo
        syncRefreshInterval = dependencies.syncRefreshInterval
        devices = DeviceSyncModel(service: dependencies.sync, ownDeviceID: dependencies.deviceInfo.deviceID)
        isLocked = !dependencies.startsUnlocked
        biometry = dependencies.authenticator.biometryKind()
        supportsOwnIdentifier = dependencies.tracking.supportsAdvertisingIdentifier
        trackingStatus = dependencies.tracking.currentStatus()
        if dependencies.startsUnlocked {
            refreshIdentifier()
            Task { await startSyncing() }
        }
        Task { await loadOwnDeviceName() }
    }

    private func loadOwnDeviceName() async {
        if ownDeviceName == nil {
            ownDeviceName = await deviceInfo.displayName()
        }
    }

    // MARK: - 表示

    /// 画面に出す IDFA。取得できないときは全桁 0
    var displayedIdentifier: AdvertisingIdentifier {
        ownIdentifier ?? .zero
    }

    /// 内容を隠す画面（アプリスイッチャーのスナップショット・画面収録中）を重ねるか。ロック画面には IDFA が無いので重ねない
    var showsPrivacyCover: Bool {
        guard !isLocked else {
            return false
        }
        return !isInForeground || (isCapturingScreen && settings.hidesWhileCapturing)
    }

    // MARK: - ロック

    /// scenePhase の変化を受け取る。バックグラウンドに移ったら時刻を覚え、戻ったときに自動ロックの時間を過ぎていればロックする
    func scenePhaseChanged(_ phase: ScenePhase, now: Date = .now) {
        switch phase {
        case .active:
            isInForeground = true
            if let backgroundedAt {
                self.backgroundedAt = nil
                if settings.autoLock.shouldLock(backgroundedAt: backgroundedAt, now: now) {
                    lock()
                }
            }
            if isLocked {
                startAutomaticUnlockIfNeeded()
            } else {
                refreshTracking()
                Task { await requestTrackingIfNeeded() }
                startRefreshLoop()
            }
        case .inactive:
            isInForeground = false
        case .background:
            isInForeground = false
            // Mac の Touch ID・パスワードのダイアログは、アプリを非アクティブにする。本人確認の途中はロックの判定に使わない
            guard !isAuthenticating else {
                return
            }
            stopRefreshLoop()
            if backgroundedAt == nil {
                backgroundedAt = now
            }
            if settings.autoLock == .immediately {
                lock()
            }
            // 次に前面に戻ったときは、また自動で本人確認を始める
            suppressesAutomaticUnlock = false
        @unknown default:
            break
        }
    }

    /// 今すぐロックする（ヘッダーのロックボタン）。自分でロックしたときは、自動では本人確認を始めない
    func lockNow() {
        lock()
        suppressesAutomaticUnlock = true
    }

    /// 本人確認をして、成功したらロックを解除する
    func unlock() async {
        guard isLocked, !isAuthenticating else {
            return
        }
        isAuthenticating = true
        biometry = authenticator.biometryKind()
        let outcome = await authenticator.authenticate(
            reason: String(localized: "Verify your identity to show your advertising identifier.")
        )
        isAuthenticating = false
        lastAuthenticationOutcome = outcome
        guard outcome == .success else {
            suppressesAutomaticUnlock = true
            return
        }
        isLocked = false
        refreshTracking()
        // 起動ごと（ロックを解除するたび）に、この端末のレコードを書いて一覧を読み直す（仕様書 3.4）
        Task { await startSyncing() }
        await requestTrackingIfNeeded()
    }

    /// メニューバーを開いたときの本人確認（Mac。仕様書 4 章）。メインのウインドウのロックは変えない
    func authenticateForMenuBar() async -> Bool {
        biometry = authenticator.biometryKind()
        let outcome = await authenticator.authenticate(
            reason: String(localized: "Verify your identity to show your advertising identifier.")
        )
        guard outcome == .success else {
            return false
        }
        refreshTracking()
        Task { await devices.refresh() }
        return true
    }

    private func lock() {
        isLocked = true
        lastAuthenticationOutcome = nil
        stopRefreshLoop()
        devices.concealAll()
    }

    private func startAutomaticUnlockIfNeeded() {
        guard isLocked, !isAuthenticating, !suppressesAutomaticUnlock else {
            return
        }
        Task { await unlock() }
    }

    // MARK: - トラッキング

    /// 許可状態と IDFA を読み直す（設定アプリで変えて戻ってきたときなど）
    func refreshTracking() {
        trackingStatus = tracking.currentStatus()
        refreshIdentifier()
    }

    /// まだ決まっていなければ、許可のダイアログを出す（初回のロック解除のあと。仕様書 3.2）
    func requestTrackingIfNeeded() async {
        // IDFA を取得できないプラットフォームでは、使わない許可を求めない
        guard supportsOwnIdentifier, !isLocked, trackingStatus == .notDetermined, !isRequestingTracking else {
            return
        }
        isRequestingTracking = true
        defer { isRequestingTracking = false }
        // 本人確認のダイアログが閉じきって、アプリが前面に戻ってから出す（前面でないと許可のダイアログは出ない）
        try? await Task.sleep(for: trackingPromptDelay)
        guard !isLocked, isInForeground else {
            return
        }
        trackingStatus = await tracking.requestAuthorization()
        refreshIdentifier()
        // 許可状態が変わったので、この端末のレコードを書き直す
        await devices.refresh(uploading: await ownRecord())
    }

    private func refreshIdentifier() {
        guard supportsOwnIdentifier, trackingStatus.allowsIdentifier else {
            ownIdentifier = nil
            return
        }
        let identifier = tracking.advertisingIdentifier()
        ownIdentifier = identifier.isZero ? nil : identifier
    }

    // MARK: - iCloud の同期

    /// この端末のレコードを書いてから一覧を読み、前面のあいだは読み直し続ける
    private func startSyncing() async {
        startRefreshLoop()
        await devices.refresh(uploading: await ownRecord())
    }

    /// 他の端末の一覧を読み直す（引っ張って更新）
    func refreshDevices() async {
        await devices.refresh()
    }

    /// 「このデバイスの IDFA を同期」を切り替える。オフにしたら、この端末のレコードを消す（仕様書 3.5）
    func setSyncsThisDevice(_ isOn: Bool) async {
        settings.syncsThisDevice = isOn
        if isOn {
            await devices.refresh(uploading: await ownRecord())
        } else {
            await devices.deleteOwnRecord()
            await devices.refresh()
        }
    }

    /// 自分の Apple ID のレコードをすべて消す。同期をオンにしている端末は、次に開いたときに書き直す
    func deleteAllSyncedData() async -> Bool {
        await devices.deleteAll()
    }

    /// 同期するこの端末のレコード。同期をオフにしている・IDFA を取得できないプラットフォームでは nil
    private func ownRecord() async -> DeviceRecord? {
        guard settings.syncsThisDevice, supportsOwnIdentifier else {
            return nil
        }
        await loadOwnDeviceName()
        return DeviceRecord(
            id: deviceInfo.deviceID,
            name: ownDeviceName ?? "",
            platform: deviceInfo.platform,
            identifier: ownIdentifier,
            trackingStatus: trackingStatus,
            updatedAt: .now
        )
    }

    private func startRefreshLoop() {
        guard refreshLoop == nil, !isLocked else {
            return
        }
        let interval = syncRefreshInterval
        refreshLoop = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard let self, !Task.isCancelled else {
                    return
                }
                if !self.isLocked, self.isInForeground {
                    await self.devices.refresh()
                }
            }
        }
    }

    private func stopRefreshLoop() {
        refreshLoop?.cancel()
        refreshLoop = nil
    }

    // MARK: - コピー

    /// IDFA を大文字・ハイフン付きでコピーする。60 秒後にクリップボードから消える
    func copy(_ identifier: AdvertisingIdentifier) {
        clipboard.copy(identifier.value, lifetime: Self.clipboardLifetime)
        copyCount += 1
    }
}
