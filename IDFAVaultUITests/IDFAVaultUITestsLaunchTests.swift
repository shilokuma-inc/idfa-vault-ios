//
//  IDFAVaultUITestsLaunchTests.swift
//  IDFAVaultUITests
//
//  Created by 村石 拓海 on 2024/05/12.
//

import XCTest

final class IDFAVaultUITestsLaunchTests: XCTestCase {
    override static var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        // 本人確認のダイアログを出さずに、ロック画面から解除までを流す
        app.launchArguments += ["-ui-testing"]
        app.launch()

        // 起動直後のスクリーンショットをテスト結果に添付する
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
