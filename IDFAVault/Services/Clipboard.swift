//
//  Clipboard.swift
//  IDFAVault
//
//  IDFA のコピー（仕様書 3.3）。コピーした値は 60 秒後にクリップボードから消す。
//  iOS・visionOS は UIPasteboard の expirationDate、Mac は 60 秒後に内容が変わっていなければ消す。
//

import Foundation
#if canImport(UIKit)
import UIKit
import UniformTypeIdentifiers
#elseif canImport(AppKit)
import AppKit
#endif

/// クリップボードに書くもの。テストでは偽物に差し替える
protocol ClipboardWriting {
    /// text をコピーし、lifetime 秒後にクリップボードから消す
    func copy(_ text: String, lifetime: TimeInterval)
}

struct SystemClipboard: ClipboardWriting {
    func copy(_ text: String, lifetime: TimeInterval) {
        #if canImport(UIKit)
        UIPasteboard.general.setItems(
            [[UTType.utf8PlainText.identifier: text]],
            options: [.expirationDate: Date.now.addingTimeInterval(lifetime)]
        )
        #elseif canImport(AppKit)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let changeCount = pasteboard.changeCount
        Task {
            try? await Task.sleep(for: .seconds(lifetime))
            // ほかのアプリが書き換えていたら（ユーザーが別のものをコピーしたら）消さない
            if NSPasteboard.general.changeCount == changeCount {
                NSPasteboard.general.clearContents()
            }
        }
        #endif
    }
}
