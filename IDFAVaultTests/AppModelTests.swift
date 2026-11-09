//
//  AppModelTests.swift
//  IDFAVaultTests
//
//  ロック（仕様書 3.1）・トラッキングの許可（3.2）・コピー（3.3）の流れを、偽物のサービスで確かめる。
//

import Foundation
@testable import IDFAVault
import SwiftUI
import Testing

struct AppModelTests {
    private static let identifier = UITesting.sampleIdentifier

    private final class RecordingClipboard: ClipboardWriting {
        private(set) var copies: [(text: String, lifetime: TimeInterval)] = []

        func copy(_ text: String, lifetime: TimeInterval) {
            copies.append((text, lifetime))
        }
    }

    private final class CountingAuthenticator: Authenticating {
        var outcome: AuthenticationOutcome
        private(set) var count = 0

        init(outcome: AuthenticationOutcome) {
            self.outcome = outcome
        }

        func biometryKind() -> BiometryKind {
            .faceID
        }

        func authenticate(reason: String) async -> AuthenticationOutcome {
            count += 1
            return outcome
        }
    }

    private func makeModel(
        authenticator: any Authenticating = StubAuthenticator(kind: .faceID, outcome: .success),
        tracking: StubTrackingProvider = StubTrackingProvider(status: .authorized, identifier: identifier),
        clipboard: any ClipboardWriting = NoopClipboard(),
        autoLock: AutoLockTiming = .immediately
    ) -> AppModel {
        let model = AppModel(dependencies: AppDependencies(
            authenticator: authenticator,
            tracking: tracking,
            clipboard: clipboard,
            defaults: .volatile(named: "tests.\(UUID().uuidString)"),
            trackingPromptDelay: .zero
        ))
        model.settings.autoLock = autoLock
        return model
    }

    // MARK: - ロック

    @Test
    func startsLockedAndUnlocksAfterAuthentication() async {
        let model = makeModel()
        #expect(model.isLocked)
        #expect(model.ownIdentifier == nil)

        await model.unlock()

        #expect(!model.isLocked)
        #expect(model.ownIdentifier == Self.identifier)
        #expect(model.lastAuthenticationOutcome == .success)
    }

    @Test
    func staysLockedWhenAuthenticationFails() async {
        let model = makeModel(authenticator: StubAuthenticator(kind: .faceID, outcome: .failed))

        await model.unlock()

        #expect(model.isLocked)
        #expect(model.lastAuthenticationOutcome == .failed)
    }

    /// 取り消したあとに前面へ戻っても、本人確認のダイアログを繰り返し出さない
    @Test
    func doesNotPromptAgainAfterCancellationUntilBackgrounded() async {
        let authenticator = CountingAuthenticator(outcome: .cancelled)
        let model = makeModel(authenticator: authenticator)

        await model.unlock()
        model.scenePhaseChanged(.inactive)
        model.scenePhaseChanged(.active)
        await Task.yield()
        #expect(authenticator.count == 1)

        // バックグラウンドを挟めば、戻ったときにまた本人確認を始める
        authenticator.outcome = .success
        model.scenePhaseChanged(.background)
        model.scenePhaseChanged(.active)
        await waitUntil { !model.isLocked }
        #expect(authenticator.count == 2)
    }

    @Test
    func locksImmediatelyWhenMovingToTheBackground() async {
        let model = makeModel(autoLock: .immediately)
        await model.unlock()

        model.scenePhaseChanged(.inactive)
        #expect(!model.isLocked)
        #expect(model.showsPrivacyCover, "アプリスイッチャーのスナップショットに IDFA を映さない")

        model.scenePhaseChanged(.background)
        #expect(model.isLocked)
    }

    @Test
    func locksOnReturnOnlyAfterTheAutoLockInterval() async {
        let model = makeModel(autoLock: .afterOneMinute)
        await model.unlock()
        let backgroundedAt = Date(timeIntervalSince1970: 1_000)

        model.scenePhaseChanged(.background, now: backgroundedAt)
        #expect(!model.isLocked)
        #expect(model.showsPrivacyCover)
        model.scenePhaseChanged(.active, now: backgroundedAt.addingTimeInterval(59))
        #expect(!model.isLocked)
        #expect(!model.showsPrivacyCover)

        model.scenePhaseChanged(.background, now: backgroundedAt.addingTimeInterval(100))
        model.scenePhaseChanged(.active, now: backgroundedAt.addingTimeInterval(160))
        #expect(model.isLocked)
    }

    @Test
    func lockNowLocksWithoutPromptingAutomatically() async {
        let authenticator = CountingAuthenticator(outcome: .success)
        let model = makeModel(authenticator: authenticator)
        await model.unlock()

        model.lockNow()
        model.scenePhaseChanged(.inactive)
        model.scenePhaseChanged(.active)
        await Task.yield()

        #expect(model.isLocked)
        #expect(authenticator.count == 1)
    }

    // MARK: - トラッキング

    @Test
    func requestsTrackingAfterTheFirstUnlock() async {
        let tracking = StubTrackingProvider(status: .notDetermined, identifier: Self.identifier, requestResult: .authorized)
        let model = makeModel(tracking: tracking)
        #expect(tracking.requestCount == 0, "ロックを解除するまでは許可のダイアログを出さない")

        await model.unlock()

        #expect(tracking.requestCount == 1)
        #expect(model.trackingStatus == .authorized)
        #expect(model.ownIdentifier == Self.identifier)
    }

    /// 未許可のときは全桁 0 を出し、IDFA は持たない（仕様書 3.2）
    @Test
    func deniedTrackingShowsZeros() async {
        let tracking = StubTrackingProvider(status: .notDetermined, identifier: Self.identifier, requestResult: .denied)
        let model = makeModel(tracking: tracking)

        await model.unlock()

        #expect(model.trackingStatus == .denied)
        #expect(model.ownIdentifier == nil)
        #expect(model.displayedIdentifier.isZero)
    }

    @Test
    func authorizedButZeroIdentifierIsTreatedAsUnavailable() async {
        let model = makeModel(tracking: StubTrackingProvider(status: .authorized, identifier: .zero))

        await model.unlock()

        #expect(model.ownIdentifier == nil)
    }

    // MARK: - コピー

    /// 大文字・ハイフン付きでコピーし、60 秒で消す（仕様書 3.3）
    @Test
    func copiesTheIdentifierForSixtySeconds() async {
        let clipboard = RecordingClipboard()
        let model = makeModel(clipboard: clipboard)
        await model.unlock()

        model.copy(Self.identifier)

        #expect(clipboard.copies.count == 1)
        #expect(clipboard.copies.first?.text == "6D92078A-8246-4BA4-AE5B-76104861E7DC")
        #expect(clipboard.copies.first?.lifetime == 60)
        #expect(model.copyCount == 1)
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<100 where !condition() {
            await Task.yield()
        }
    }
}
