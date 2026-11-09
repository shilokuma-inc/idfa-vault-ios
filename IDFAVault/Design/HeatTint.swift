//
//  HeatTint.swift
//  IDFAVault
//
//  テーマ「ヒートティント」の色とグラデーション（仕様書 6.2・6.3）。
//  熱処理したチタンのように、紺 → 紫 → シアンへ色が移ろう暗い金属。ライトモードでも同じ配色にする。
//

import SwiftUI

extension Color {
    /// 0xRRGGBB の 16 進数と不透明度から色を作る
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension LinearGradient {
    /// 上から下へのグラデーション（CSS の 180deg）
    static func vertical(_ stops: [Gradient.Stop]) -> LinearGradient {
        LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
    }

    /// CSS の `linear-gradient(<角度>deg, …)` と同じ向きのグラデーション。0° が上向き、時計回りに増える
    init(cssAngle degrees: Double, stops: [Gradient.Stop]) {
        let radians = degrees * .pi / 180
        let dx = sin(radians) / 2
        let dy = -cos(radians) / 2
        self.init(
            stops: stops,
            startPoint: UnitPoint(x: 0.5 - dx, y: 0.5 - dy),
            endPoint: UnitPoint(x: 0.5 + dx, y: 0.5 + dy)
        )
    }
}

enum HeatTint {
    // MARK: - 色

    /// 背景（ベース）
    static let base = Color(hex: 0x03030A)
    /// 本文の文字
    static let text = Color(hex: 0xE6EBFA)
    /// 補足の文字
    static let secondaryText = Color(hex: 0xDCE3FA, opacity: 0.72)
    /// さらに弱い補足の文字（脚注など）
    static let tertiaryText = Color(hex: 0xDCE3FA, opacity: 0.66)
    /// 等幅・大文字のセクション見出し
    static let sectionHeader = Color(hex: 0xB3BDEB)
    /// リンク・アイコンボタン
    static let link = Color(hex: 0xB7C6F5)
    /// アイコン
    static let icon = Color(hex: 0xDCE3FA)
    /// 許可済み（緑）
    static let allowed = Color(hex: 0x3DEB6B)
    /// 未許可（オレンジ）
    static let warning = Color(hex: 0xFF9F0A)
    /// 未許可のバッジの文字
    static let warningLight = Color(hex: 0xFFB340)
    /// 削除（赤）
    static let destructive = Color(hex: 0xFF6961)
    /// 主ボタンの上の文字
    static let ink = Color(hex: 0x07081A)
    /// 溝の下半分・細い光の筋の色（淡い紫）
    static let lavender = Color(hex: 0xAAA0F0)

    // MARK: - 金属のグラデーション

    /// インゴット外周（IDFA のカードの縁の斜面）
    static let ingotRim = LinearGradient(cssAngle: 165, stops: [
        .init(color: Color(hex: 0xF4EFFF), location: 0),
        .init(color: Color(hex: 0x9D84E0), location: 0.06),
        .init(color: Color(hex: 0x2A2565), location: 0.18),
        .init(color: Color(hex: 0x1F4F8C), location: 0.36),
        .init(color: Color(hex: 0x0B0E24), location: 0.56),
        .init(color: Color(hex: 0x3A2F7C), location: 0.74),
        .init(color: Color(hex: 0x0A1630), location: 0.88),
        .init(color: Color(hex: 0x8FC0EE), location: 1)
    ])

    /// インゴット表面のベース
    static let ingotFace = LinearGradient(cssAngle: 155, stops: [
        .init(color: Color(hex: 0x262C5C), location: 0),
        .init(color: Color(hex: 0x121638), location: 0.40),
        .init(color: Color(hex: 0x18284F), location: 0.66),
        .init(color: Color(hex: 0x0A0D22), location: 1)
    ])

    /// 一覧・設定のグループの縁（1.5pt）
    static let plateRim = LinearGradient(cssAngle: 165, stops: [
        .init(color: Color(hex: 0xF1ECFF), location: 0),
        .init(color: Color(hex: 0x6C5BC4), location: 0.14),
        .init(color: Color(hex: 0x0B0E24), location: 0.45),
        .init(color: Color(hex: 0x2B6AA8), location: 0.80),
        .init(color: Color(hex: 0xCFE6FF), location: 1)
    ])

    /// 一覧・設定のグループの面
    static let plateFace = LinearGradient(
        colors: [Color(hex: 0x171B3D), Color(hex: 0x070919)],
        startPoint: .top,
        endPoint: .bottom
    )

    /// 主ボタン（コピー・ロック解除など）の面
    static let primaryFace = LinearGradient.vertical([
        .init(color: Color(hex: 0xF2F0FF), location: 0),
        .init(color: Color(hex: 0xC9C6F3), location: 0.44),
        .init(color: Color(hex: 0x6A78C4), location: 0.52),
        .init(color: Color(hex: 0x9FBDE6), location: 0.78),
        .init(color: Color(hex: 0xDBE8FA), location: 1)
    ])

    /// 主ボタンの縁
    static let primaryRim = LinearGradient.vertical([
        .init(color: .white, location: 0),
        .init(color: Color(hex: 0x9D90E8), location: 0.5),
        .init(color: Color(hex: 0x1A2148), location: 1)
    ])

    /// 副ボタン（共有・パスコードなど）の面
    static let secondaryFace = LinearGradient.vertical([
        .init(color: Color(hex: 0x2D3366), location: 0),
        .init(color: Color(hex: 0x12163A), location: 0.48),
        .init(color: Color(hex: 0x05061A), location: 0.52),
        .init(color: Color(hex: 0x0E1530), location: 1)
    ])

    /// 副ボタンの縁
    static let secondaryRim = LinearGradient.vertical([
        .init(color: Color(hex: 0xD6D0FF), location: 0),
        .init(color: Color(hex: 0x3A3F8A), location: 0.5),
        .init(color: Color(hex: 0x070A1C), location: 1)
    ])

    /// 見出しの金属文字（大見出し・アプリ名）
    static let headingMetal = LinearGradient.vertical([
        .init(color: .white, location: 0),
        .init(color: Color(hex: 0xD6DCFB), location: 0.38),
        .init(color: Color(hex: 0x4A3F8F), location: 0.50),
        .init(color: Color(hex: 0x4D86C4), location: 0.60),
        .init(color: Color(hex: 0xCFE1F7), location: 0.84),
        .init(color: .white, location: 1)
    ])

    /// IDFA の金属文字
    static let identifierMetal = LinearGradient.vertical([
        .init(color: .white, location: 0),
        .init(color: Color(hex: 0xDFE3FB), location: 0.42),
        .init(color: Color(hex: 0x9B92E6), location: 0.52),
        .init(color: Color(hex: 0xA9CFF2), location: 0.66),
        .init(color: Color(hex: 0xF3F6FF), location: 1)
    ])

    /// 小さなボタン台（ヘッダーのロック・設定）の縁
    static let toolRim = LinearGradient(cssAngle: 160, stops: [
        .init(color: Color(hex: 0xF1ECFF), location: 0),
        .init(color: Color(hex: 0x8A74D6), location: 0.20),
        .init(color: Color(hex: 0x1A2148), location: 0.50),
        .init(color: Color(hex: 0x3F8AD0), location: 0.78),
        .init(color: Color(hex: 0xE3F0FF), location: 1)
    ])

    /// 小さなボタン台（ヘッダーのロック・設定）の面
    static let toolFace = LinearGradient.vertical([
        .init(color: Color(hex: 0x252B56), location: 0),
        .init(color: Color(hex: 0x0D1028), location: 0.55),
        .init(color: Color(hex: 0x131D3B), location: 1)
    ])

    /// アイコン台（40×40）の面
    static let iconFace = LinearGradient(cssAngle: 160, stops: [
        .init(color: Color(hex: 0x3A3A86), location: 0),
        .init(color: Color(hex: 0x10163A), location: 0.60),
        .init(color: Color(hex: 0x1D4A80), location: 1)
    ])

    /// 選んでいる行（サイドバー）の面
    static let selectedRowFace = LinearGradient(cssAngle: 155, stops: [
        .init(color: Color(hex: 0x2C3270), location: 0),
        .init(color: Color(hex: 0x151A45), location: 0.55),
        .init(color: Color(hex: 0x1D3462), location: 1)
    ])

    /// 選んでいる行（サイドバー）の縁
    static let selectedRowRim = LinearGradient(cssAngle: 160, stops: [
        .init(color: Color(hex: 0xF4EFFF), location: 0),
        .init(color: Color(hex: 0x9D84E0), location: 0.20),
        .init(color: Color(hex: 0x1F4F8C), location: 0.60),
        .init(color: Color(hex: 0x8FC0EE), location: 1)
    ])

    /// トグルのオン（緑）
    static let toggleOn = LinearGradient.vertical([
        .init(color: Color(hex: 0x8AF5A8), location: 0),
        .init(color: Color(hex: 0x30D158), location: 0.48),
        .init(color: Color(hex: 0x1C8F3C), location: 0.52),
        .init(color: Color(hex: 0x2FBF55), location: 1)
    ])

    /// トグルのつまみ
    static let toggleKnob = LinearGradient.vertical([
        .init(color: .white, location: 0),
        .init(color: Color(hex: 0xE4E8F6), location: 0.45),
        .init(color: Color(hex: 0x9AA3C8), location: 0.52),
        .init(color: Color(hex: 0xDFE4F6), location: 1)
    ])

    // MARK: - 光の筋

    /// 112° の細い光の筋。center の位置（0〜1）に、幅 width で opacity の明るさの線を引く
    static func streak(
        at center: Double,
        width: Double = 0.06,
        color: Color = Color(hex: 0xDCD7FF),
        opacity: Double = 0.45
    ) -> LinearGradient {
        LinearGradient(cssAngle: 112, stops: [
            .init(color: color.opacity(0), location: max(0, center - width / 2)),
            .init(color: color.opacity(opacity), location: center),
            .init(color: color.opacity(0), location: min(1, center + width / 2))
        ])
    }

    /// 青紫〜シアンの淡い照り返し
    static func sheen(from start: Double, to end: Double, opacity: Double = 0.2) -> LinearGradient {
        let middle = (start + end) / 2
        return LinearGradient(cssAngle: 112, stops: [
            .init(color: Color(hex: 0x648CE6, opacity: 0), location: start),
            .init(color: Color(hex: 0x786EE6, opacity: opacity), location: middle),
            .init(color: Color(hex: 0x50AAE6, opacity: opacity * 0.6), location: middle + (end - middle) * 0.5),
            .init(color: Color(hex: 0x648CE6, opacity: 0), location: end)
        ])
    }
}
