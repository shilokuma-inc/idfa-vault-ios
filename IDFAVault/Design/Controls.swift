//
//  Controls.swift
//  IDFAVault
//
//  ヒートティントのボタン・トグル・バッジ・溝・見出し。どれも角丸を使わない（仕様書 6.4）。
//

import SwiftUI

// MARK: - ボタン

/// 金属のボタン。主ボタン（明るい金属・濃い文字）と副ボタン（暗い金属・明るい文字）
struct MetalButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
    }

    var kind: Kind = .primary
    var chamfer: CGFloat = 12
    var minHeight: CGFloat = 53
    var fillsWidth = true
    var alignment: Alignment = .center

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(kind == .primary ? HeatTint.ink : HeatTint.text)
            .padding(.horizontal, 24)
            .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: minHeight, alignment: alignment)
            .background {
                MetalSurface(
                    chamfer: chamfer,
                    rimWidth: 1.5,
                    rim: kind == .primary ? HeatTint.primaryRim : HeatTint.secondaryRim
                ) {
                    kind == .primary ? HeatTint.primaryFace : HeatTint.secondaryFace
                }
                .shadow(color: .black.opacity(kind == .primary ? 0.6 : 0.4), radius: 9, y: 12)
            }
            .contentShape(ChamferedRect(chamfer: chamfer))
            .brightness(configuration.isPressed ? -0.12 : 0)
            .opacity(isEnabled ? 1 : 0.5)
    }
}

extension ButtonStyle where Self == MetalButtonStyle {
    /// 主ボタン（全幅）
    static var metalPrimary: MetalButtonStyle { MetalButtonStyle(kind: .primary) }
    /// 副ボタン（全幅）
    static var metalSecondary: MetalButtonStyle { MetalButtonStyle(kind: .secondary) }

    static func metal(
        _ kind: MetalButtonStyle.Kind,
        chamfer: CGFloat = 12,
        minHeight: CGFloat = 53,
        fillsWidth: Bool = true,
        alignment: Alignment = .center
    ) -> MetalButtonStyle {
        MetalButtonStyle(kind: kind, chamfer: chamfer, minHeight: minHeight, fillsWidth: fillsWidth, alignment: alignment)
    }
}

// MARK: - トグル

/// 面取りのトグル（54×32、つまみは 26×26）。オンは緑の金属、オフは暗い金属
struct ChamferToggleStyle: ToggleStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        // 変えられないトグル（起動時の生体認証）は、項目名は薄くせず、つまみの台だけを薄くする
        Group {
            if isEnabled {
                Button {
                    configuration.isOn.toggle()
                } label: {
                    row(configuration)
                }
                .buttonStyle(.plain)
            } else {
                row(configuration)
            }
        }
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) {
                configuration.label
            }
        }
    }

    private func row(_ configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.label
                .frame(maxWidth: .infinity, alignment: .leading)
            track(isOn: configuration.isOn)
        }
        .contentShape(Rectangle())
    }

    private func track(isOn: Bool) -> some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            if isOn {
                ChamferedRect(chamfer: 8)
                    .fill(HeatTint.toggleOn)
            } else {
                MetalSurface(chamfer: 8, rimWidth: 1.5, rim: HeatTint.secondaryRim) {
                    HeatTint.secondaryFace
                }
            }
            ChamferedRect(chamfer: 6)
                .fill(HeatTint.toggleKnob)
                .frame(width: 26, height: 26)
                .padding(3)
                .shadow(color: .black.opacity(0.35), radius: 1.5, y: 1)
        }
        .frame(width: 54, height: 32)
        .opacity(isEnabled ? 1 : 0.55)
        .animation(.snappy(duration: 0.2), value: isOn)
    }
}

extension ToggleStyle where Self == ChamferToggleStyle {
    static var chamfer: ChamferToggleStyle { ChamferToggleStyle() }
}

// MARK: - バッジ

/// トラッキングの許可状態などを示す、左右を尖らせた六角形のバッジ
struct StatusBadge: View {
    var title: LocalizedStringResource
    var color: Color
    var glows = false
    var fontSize: CGFloat = 12

    var body: some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(color)
                .frame(width: 6, height: 6)
                .rotationEffect(.degrees(45))
                .shadow(color: glows ? color : .clear, radius: 3)
            Text(title)
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundStyle(color)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(PointedCapsule(point: 6).fill(.black.opacity(0.55)))
    }
}

// MARK: - 溝・見出し

/// 溝（区切り線）。高さ 2pt で、上半分が黒、下半分が淡い紫
struct Groove: View {
    enum Axis {
        case horizontal
        case vertical
    }

    var axis: Axis = .horizontal
    var highlight: Double = 0.26

    var body: some View {
        let stack = Group {
            Rectangle().fill(.black.opacity(0.8))
            Rectangle().fill(HeatTint.lavender.opacity(highlight))
        }
        switch axis {
        case .horizontal:
            VStack(spacing: 0) { stack }
                .frame(height: 2)
                .accessibilityHidden(true)
        case .vertical:
            HStack(spacing: 0) { stack }
                .frame(width: 2)
                .accessibilityHidden(true)
        }
    }
}

/// 等幅・大文字のセクション見出し（例: SAME APPLE ID）と溝。右に補足を置ける
struct SectionHeader<Trailing: View>: View {
    var title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 10) {
            Text(verbatim: title)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .tracking(1.7)
                .foregroundStyle(HeatTint.sectionHeader)
                .lineLimit(1)
                .layoutPriority(1)
                .accessibilityAddTraits(.isHeader)
            Groove()
                .frame(maxWidth: .infinity)
            trailing
                .font(.caption)
                .foregroundStyle(HeatTint.tertiaryText)
                .lineLimit(1)
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}

// MARK: - 文字

extension View {
    /// 見出しの金属文字（大見出し・アプリ名）。文字の形でグラデーションを塗り、黒い落ち影を付ける
    func headingMetal() -> some View {
        foregroundStyle(HeatTint.headingMetal)
            .shadow(color: .black.opacity(0.9), radius: 1, y: 2)
    }

    /// IDFA の金属文字
    func identifierMetal() -> some View {
        foregroundStyle(HeatTint.identifierMetal)
            .shadow(color: .black.opacity(0.9), radius: 0.5, y: 1)
    }
}

// MARK: - アイコン台

/// 端末などのアイコンを載せる面取りの台（40×40）
struct IconPlate: View {
    var systemImage: String
    var size: CGFloat = 40
    var isHighlighted = false
    var isDimmed = false

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(isHighlighted ? HeatTint.ink : (isDimmed ? HeatTint.secondaryText : HeatTint.icon))
            .frame(width: size, height: size)
            .background {
                ChamferedRect(chamfer: size / 4)
                    .fill(plateStyle)
                    .overlay {
                        if !isHighlighted && !isDimmed {
                            ChamferedRect(chamfer: size / 4)
                                .fill(HeatTint.streak(at: 0.4, width: 0.2, opacity: 0.38))
                        }
                    }
            }
            .accessibilityHidden(true)
    }

    private var plateStyle: AnyShapeStyle {
        if isHighlighted {
            return AnyShapeStyle(HeatTint.primaryFace)
        }
        return isDimmed ? AnyShapeStyle(Color(hex: 0x05061A)) : AnyShapeStyle(HeatTint.iconFace)
    }
}

/// ヘッダーの小さなボタン（44×44）。台は呼び出し側が toolBackground で付ける
struct ToolButtonLabel: View {
    var systemImage: String
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(HeatTint.icon)
            .frame(width: size, height: size)
            .contentShape(Rectangle())
    }
}
