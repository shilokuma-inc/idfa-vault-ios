//
//  AutoLock.swift
//  IDFAVault
//
//  自動ロックのタイミング（仕様書 3.1・3.5）。バックグラウンドに移ってから、どれだけ経ったら戻ったときにロックするか。
//

import Foundation

enum AutoLockTiming: String, CaseIterable, Identifiable, Sendable {
    case immediately
    case afterOneMinute
    case afterFiveMinutes

    var id: Self { self }

    /// バックグラウンドに移ってから、ロックするまでの秒数
    var interval: TimeInterval {
        switch self {
        case .immediately:
            0
        case .afterOneMinute:
            60
        case .afterFiveMinutes:
            300
        }
    }

    /// 設定の選択肢の文言
    var title: LocalizedStringResource {
        switch self {
        case .immediately:
            "Immediately"
        case .afterOneMinute:
            "After 1 Minute"
        case .afterFiveMinutes:
            "After 5 Minutes"
        }
    }

    /// ロック画面の下に出す説明
    var lockFootnote: LocalizedStringResource {
        switch self {
        case .immediately:
            "Locks automatically when the app moves to the background"
        case .afterOneMinute:
            "Locks automatically 1 minute after the app moves to the background"
        case .afterFiveMinutes:
            "Locks automatically 5 minutes after the app moves to the background"
        }
    }

    /// バックグラウンドから戻ったときにロックするか。backgroundedAt はバックグラウンドに移った時刻
    func shouldLock(backgroundedAt: Date, now: Date) -> Bool {
        now.timeIntervalSince(backgroundedAt) >= interval
    }
}
