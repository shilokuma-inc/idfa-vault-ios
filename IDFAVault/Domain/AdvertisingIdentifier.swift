//
//  AdvertisingIdentifier.swift
//  IDFAVault
//
//  IDFA（広告識別子）の値と、画面に出すときの書式。
//

import Foundation

/// IDFA の値。大文字・ハイフン付きの 36 文字（例: 6D92078A-8246-4BA4-AE5B-76104861E7DC）
struct AdvertisingIdentifier: Hashable, Sendable {
    /// トラッキングが許可されていないときに OS が返す、全桁 0 の値
    static let zero = AdvertisingIdentifier(uuid: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)))

    /// 大文字・ハイフン付きの文字列。コピーと共有にはこの値をそのまま使う
    let value: String

    init(uuid: UUID) {
        value = uuid.uuidString.uppercased()
    }

    /// 文字列から作る。UUID の形でなければ nil
    init?(_ string: String) {
        guard let uuid = UUID(uuidString: string) else {
            return nil
        }
        self.init(uuid: uuid)
    }

    /// 全桁 0（取得できない）か。全桁 0 は「取得できない」と同じ扱いにし、同期しない（仕様書 3.2）
    var isZero: Bool {
        self == Self.zero
    }

    /// iPhone で 2 行に分けて出すときの各行（`6D92078A-8246-4BA4-` / `AE5B-76104861E7DC`）
    var twoLines: (first: String, second: String) {
        let groups = value.split(separator: "-")
        guard groups.count == 5 else {
            return (value, "")
        }
        return (groups[0...2].joined(separator: "-") + "-", groups[3...4].joined(separator: "-"))
    }

    /// 他の端末の IDFA の伏せ字（例: `A1C4••••-••••-9F21`）。先頭 4 桁と末尾 4 桁だけを見せる
    var masked: String {
        "\(value.prefix(4))••••-••••-\(value.suffix(4))"
    }

    /// サイドバーなど幅の狭いところの伏せ字（例: `A1C4••••-9F21`）
    var shortMasked: String {
        "\(value.prefix(4))••••-\(value.suffix(4))"
    }
}
