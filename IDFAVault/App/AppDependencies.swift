//
//  AppDependencies.swift
//  IDFAVault
//
//  AppModel に渡す外のサービス。通常の起動・UI テスト・スクリーンショットの撮影・Unit テストのホストで差し替える。
//  Unit テストのホストと UI テストでは、生体認証・トラッキングのダイアログを出さない。
//

import Foundation

struct AppDependencies {
    var authenticator: any Authenticating
    var tracking: any TrackingProviding
    var clipboard: any ClipboardWriting
    var deviceInfo: any DeviceInfoProviding
    var sync: any DeviceSyncing
    var defaults: UserDefaults
    /// ロックを解除した状態で始めるか（スクリーンショットの撮影）
    var startsUnlocked = false
    /// ロック解除からトラッキングの許可のダイアログを出すまでの待ち時間
    var trackingPromptDelay: Duration = .milliseconds(600)
    /// 前面でロックを解除しているあいだ、他の端末の一覧を読み直す間隔。
    /// 別の端末で起動したら、数秒〜数十秒で一覧に出るようにする（仕様書 9 章の受け入れ条件）
    var syncRefreshInterval: Duration = .seconds(20)

    /// 起動引数と環境変数から、使うものを決める
    static func resolve(processInfo: ProcessInfo = .processInfo) -> AppDependencies {
        let arguments = processInfo.arguments
        if ScreenshotDemo.isEnabled {
            return .screenshotDemo
        }
        if arguments.contains(UITesting.launchArgument) {
            return .uiTesting(arguments: arguments)
        }
        // Unit テストのホストとして起動したときは、本人確認やダイアログを出さない
        if processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return .testHost
        }
        return .live
    }

    /// 通常の起動
    static var live: AppDependencies {
        AppDependencies(
            authenticator: LocalAuthenticator(),
            tracking: SystemTrackingProvider(),
            clipboard: SystemClipboard(),
            deviceInfo: SystemDeviceInfo(),
            sync: CloudKitDeviceSync(),
            defaults: .standard
        )
    }

    /// Unit テストのホスト。何もしない
    static var testHost: AppDependencies {
        AppDependencies(
            authenticator: StubAuthenticator(kind: .faceID, outcome: .cancelled),
            tracking: StubTrackingProvider(status: .notDetermined),
            clipboard: NoopClipboard(),
            deviceInfo: StubDeviceInfo(),
            sync: StubDeviceSync(availability: .noAccount),
            defaults: .volatile(named: "test-host")
        )
    }

    /// スクリーンショットの撮影。撮る画面（ScreenshotDemo.Scene）に合わせて、ロックの状態とトラッキングの許可を決める
    static var screenshotDemo: AppDependencies {
        let scene = ScreenshotDemo.scene ?? .home
        let defaults = UserDefaults.volatile(named: "screenshot-demo")
        // デモの値なので、Mac のウインドウをスクリーンショットから外さない
        defaults.set(false, forKey: AppSettings.hidesWhileCapturingKey)
        return AppDependencies(
            authenticator: StubAuthenticator(kind: .demo, outcome: scene == .lock ? .cancelled : .success),
            tracking: StubTrackingProvider(
                status: scene == .denied ? .denied : .authorized,
                identifier: UITesting.sampleIdentifier
            ),
            clipboard: NoopClipboard(),
            deviceInfo: StubDeviceInfo(),
            sync: StubDeviceSync(records: StubDeviceSync.demoDevices(now: .now, excluding: StubDeviceInfo().name)),
            defaults: defaults,
            startsUnlocked: scene != .lock
        )
    }

    /// UI テスト。本人確認・認証方式・トラッキングは起動引数の状態（既定は成功・Face ID・許可済み）にする
    static func uiTesting(arguments: [String]) -> AppDependencies {
        let status = UITesting.value(after: UITesting.trackingArgument, in: arguments)
            .flatMap(TrackingStatus.init(rawValue:)) ?? .authorized
        let outcome = UITesting.value(after: UITesting.authenticationArgument, in: arguments)
            .flatMap(AuthenticationOutcome.init(argument:)) ?? .success
        let biometry = UITesting.value(after: UITesting.biometryArgument, in: arguments)
            .flatMap(BiometryKind.init(argument:)) ?? .demo
        let iCloud = UITesting.value(after: UITesting.iCloudArgument, in: arguments)
        let sync = iCloud == "noAccount"
            ? StubDeviceSync(availability: .noAccount)
            : StubDeviceSync(records: iCloud == "empty" ? [] : StubDeviceSync.demoDevices(now: .now, excluding: StubDeviceInfo().name))
        let defaults = UserDefaults.volatile(named: "ui-testing")
        if arguments.contains(UITesting.allowsCaptureArgument) {
            // Mac のウインドウをスクリーンショットに写すため、「画面収録・ミラーリング中は隠す」を切る
            defaults.set(false, forKey: AppSettings.hidesWhileCapturingKey)
        }
        return AppDependencies(
            authenticator: StubAuthenticator(kind: biometry, outcome: outcome),
            tracking: StubTrackingProvider(status: status, identifier: UITesting.sampleIdentifier),
            clipboard: SystemClipboard(),
            deviceInfo: StubDeviceInfo(),
            sync: sync,
            defaults: defaults,
            trackingPromptDelay: .zero
        )
    }
}

/// UI テストとの取り決め（起動引数・デモの値）
enum UITesting {
    static let launchArgument = "-ui-testing"
    /// トラッキングの許可状態（TrackingStatus の rawValue）を続けて渡す
    static let trackingArgument = "-ui-testing-tracking"
    /// 本人確認の結果（success / cancelled / failed / unavailable）を続けて渡す
    static let authenticationArgument = "-ui-testing-authentication"
    /// 認証方式（faceID / touchID / touchIDTopButton / touchIDMac / opticID / none）を続けて渡す
    static let biometryArgument = "-ui-testing-biometry"
    /// iCloud の状態（devices（既定）/ empty / noAccount）を続けて渡す
    static let iCloudArgument = "-ui-testing-icloud"
    /// 「画面収録・ミラーリング中は隠す」を切って起動する（Mac のスクリーンショット）
    static let allowsCaptureArgument = "-ui-testing-allows-capture"
    // swiftlint:disable:next force_unwrapping
    static let sampleIdentifier = AdvertisingIdentifier("6D92078A-8246-4BA4-AE5B-76104861E7DC")!

    static func value(after argument: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: argument), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
}

extension UserDefaults {
    /// 起動のたびに中身を消す UserDefaults（UI テスト・撮影・テストのホストで、実際の設定と混ぜないため）
    static func volatile(named name: String) -> UserDefaults {
        let suiteName = "jp.shilokuma.IDFAVault.\(name)"
        // swiftlint:disable:next force_unwrapping
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

extension AuthenticationOutcome {
    /// UI テストの起動引数の値から作る
    init?(argument: String) {
        switch argument {
        case "success":
            self = .success
        case "cancelled":
            self = .cancelled
        case "failed":
            self = .failed
        case "unavailable":
            self = .unavailable
        default:
            return nil
        }
    }
}

extension BiometryKind {
    /// 撮影と UI テストの既定。そのプラットフォームの代表的な認証方式
    static var demo: BiometryKind {
        switch DeviceKind.current {
        case .mac:
            .touchID(.mac)
        case .vision:
            .opticID
        case .iPhone, .iPad:
            .faceID
        }
    }

    /// UI テストの起動引数の値から作る
    init?(argument: String) {
        switch argument {
        case "faceID":
            self = .faceID
        case "touchID":
            self = .touchID(.homeButton)
        case "touchIDTopButton":
            self = .touchID(.topButton)
        case "touchIDMac":
            self = .touchID(.mac)
        case "opticID":
            self = .opticID
        case "none":
            self = .none
        default:
            return nil
        }
    }
}

// MARK: - 偽物

/// 決まった結果を返す本人確認
struct StubAuthenticator: Authenticating {
    var kind: BiometryKind
    var outcome: AuthenticationOutcome

    func biometryKind() -> BiometryKind {
        kind
    }

    func authenticate(reason: String) async -> AuthenticationOutcome {
        outcome
    }
}

/// 決まった許可状態と IDFA を返す。許可のダイアログでは requestResult になる
final class StubTrackingProvider: TrackingProviding {
    let supportsAdvertisingIdentifier: Bool
    private(set) var status: TrackingStatus
    let identifier: AdvertisingIdentifier
    let requestResult: TrackingStatus
    private(set) var requestCount = 0

    init(
        status: TrackingStatus,
        identifier: AdvertisingIdentifier = .zero,
        requestResult: TrackingStatus? = nil,
        supportsAdvertisingIdentifier: Bool = true
    ) {
        self.supportsAdvertisingIdentifier = supportsAdvertisingIdentifier
        self.status = status
        self.identifier = identifier
        self.requestResult = requestResult ?? status
    }

    func currentStatus() -> TrackingStatus {
        status
    }

    func requestAuthorization() async -> TrackingStatus {
        requestCount += 1
        if status == .notDetermined {
            status = requestResult
        }
        return status
    }

    func advertisingIdentifier() -> AdvertisingIdentifier {
        status.allowsIdentifier ? identifier : .zero
    }
}

/// 何も書かないクリップボード
struct NoopClipboard: ClipboardWriting {
    func copy(_ text: String, lifetime: TimeInterval) {
        // 何もしない
    }
}

/// 決まった端末の情報
struct StubDeviceInfo: DeviceInfoProviding {
    var deviceID = "this-device"
    var platform: DevicePlatform = .current
    var name = DeviceKind.current == .mac ? "MacBook Pro" : (DeviceKind.current == .iPad ? "iPad Pro" : "iPhone 16 Pro")

    func displayName() async -> String {
        name
    }
}

/// メモリの上だけで端末のレコードを持つ同期
final class StubDeviceSync: DeviceSyncing {
    var availabilityResult: SyncAvailability
    private(set) var records: [String: DeviceRecord]
    private(set) var saveCount = 0
    var failsNextRequest = false

    init(availability: SyncAvailability = .available, records: [DeviceRecord] = []) {
        availabilityResult = availability
        self.records = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
    }

    func availability() async -> SyncAvailability {
        availabilityResult
    }

    func save(_ record: DeviceRecord) async throws {
        try failIfNeeded()
        saveCount += 1
        records[record.id] = record
    }

    func delete(deviceID: String) async throws {
        try failIfNeeded()
        records[deviceID] = nil
    }

    func fetchAll() async throws -> [DeviceRecord] {
        try failIfNeeded()
        return Array(records.values)
    }

    func deleteAll() async throws {
        try failIfNeeded()
        records = [:]
    }

    private func failIfNeeded() throws {
        if failsNextRequest {
            failsNextRequest = false
            throw URLError(.notConnectedToInternet)
        }
    }

    /// 撮影と UI テストで出す、ほかの端末。excluding と同じ名前の端末（この端末と同じ種類）は外す
    static func demoDevices(now: Date, excluding ownName: String? = nil) -> [DeviceRecord] {
        let devices = [
            DeviceRecord(
                id: "demo-ipad",
                name: "iPad Pro",
                platform: .iPadOS,
                identifier: AdvertisingIdentifier("A1C4B83E-5D20-4F7A-8C61-0E9B2D4C9F21"),
                trackingStatus: .authorized,
                updatedAt: now.addingTimeInterval(-120)
            ),
            DeviceRecord(
                id: "demo-mac",
                name: "MacBook Pro",
                platform: .macOS,
                identifier: AdvertisingIdentifier("C47D2E10-93AB-4F61-B8D2-5E0A7C3F1B66"),
                trackingStatus: .authorized,
                updatedAt: now.addingTimeInterval(-3_600)
            ),
            DeviceRecord(
                id: "demo-iphone",
                name: "iPhone 16 Pro",
                platform: .iOS,
                identifier: AdvertisingIdentifier("3B7E91D0-6A2F-4C85-B3E4-7D1A5F2E04C8"),
                trackingStatus: .authorized,
                updatedAt: now.addingTimeInterval(-7_200)
            ),
            DeviceRecord(
                id: "demo-ipad-mini",
                name: "iPad mini",
                platform: .iPadOS,
                identifier: nil,
                trackingStatus: .denied,
                updatedAt: now.addingTimeInterval(-86_400 * 3)
            )
        ]
        return devices.filter { $0.name != ownName }
    }
}
