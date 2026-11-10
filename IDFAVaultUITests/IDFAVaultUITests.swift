//
//  IDFAVaultUITests.swift
//  IDFAVaultUITests
//
//  Created by 村石 拓海 on 2024/05/12.
//

import XCTest

final class IDFAVaultUITests: XCTestCase {
    private static let sampleIdentifier = "6D92078A-8246-4BA4-AE5B-76104861E7DC"

    override func setUpWithError() throws {
        // UI テストでは失敗した時点で即座に止める
        continueAfterFailure = false
    }

    /// 起動するとロック画面から本人確認が始まり、成功するとこの端末の IDFA が出る。ロックするとロック画面に戻る
    @MainActor
    func testUnlockShowsIdentifierAndLockReturnsToLockScreen() throws {
        let app = launch(tracking: "authorized")

        let identifier = app.staticTexts["ownIdentifier"]
        XCTAssertTrue(identifier.waitForExistence(timeout: 10))
        XCTAssertEqual(identifier.label, Self.sampleIdentifier)

        app.buttons["copy"].tap()
        XCTAssertTrue(app.staticTexts["Copied"].waitForExistence(timeout: 3))

        app.buttons["lockNow"].tap()
        let unlock = app.buttons["unlock"]
        XCTAssertTrue(unlock.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["ownIdentifier"].exists, "ロック中は IDFA を出さない")

        unlock.tap()
        XCTAssertTrue(app.staticTexts["ownIdentifier"].waitForExistence(timeout: 5))
    }

    /// トラッキングが未許可なら、全桁 0 と「設定を開く」を出す
    @MainActor
    func testDeniedTrackingShowsZerosAndSettingsLink() throws {
        let app = launch(tracking: "denied")

        let identifier = app.staticTexts["ownIdentifier"]
        XCTAssertTrue(identifier.waitForExistence(timeout: 10))
        XCTAssertEqual(identifier.label, "00000000-0000-0000-0000-000000000000")
        XCTAssertTrue(app.buttons["Open Settings"].exists)
        XCTAssertFalse(app.buttons["copy"].exists)
    }

    /// 設定を開いて戻れる
    @MainActor
    func testSettingsOpensAndCloses() throws {
        let app = launch(tracking: "authorized")
        XCTAssertTrue(app.buttons["settings"].waitForExistence(timeout: 10))

        app.buttons["settings"].tap()
        XCTAssertTrue(app.switches["hidesWhileCapturing"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["autoLock"].exists)

        app.buttons["Back"].tap()
        XCTAssertTrue(app.staticTexts["ownIdentifier"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func launch(tracking: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing", "-ui-testing-tracking", tracking, "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        return app
    }
}
