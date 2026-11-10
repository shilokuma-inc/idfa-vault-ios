//
//  Surfaces.swift
//  IDFAVault
//
//  金属の板（縁＋面）と影。インゴット（IDFA のカード）・板（一覧・設定のグループ）・小さなボタン台に使う。
//

import SwiftUI

/// 縁（斜面）と面を重ねた面取りの板
struct MetalSurface<Face: View>: View {
    var chamfer: CGFloat
    var rimWidth: CGFloat
    var rim: LinearGradient
    @ViewBuilder var face: Face

    var body: some View {
        ZStack {
            ChamferedRect(chamfer: chamfer)
                .fill(rim)
            face
                .clipShape(ChamferedRect(chamfer: chamfer).inset(by: rimWidth))
        }
    }
}

/// インゴット（IDFA のカード）の面。ベースに照り返しと 2 本の光の筋を重ねる
struct IngotFace: View {
    var body: some View {
        ZStack {
            HeatTint.ingotFace
            HeatTint.sheen(from: 0.12, to: 0.46)
            HeatTint.streak(at: 0.25)
            HeatTint.streak(at: 0.76, width: 0.04, color: Color(hex: 0xC8E6FF), opacity: 0.24)
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.08), location: 0),
                    .init(color: .white.opacity(0), location: 0.35)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

/// 一覧・設定のグループの面。薄い光の筋を 1 本重ねる
struct PlateFace: View {
    var body: some View {
        ZStack {
            HeatTint.plateFace
            HeatTint.streak(at: 0.35, color: Color(hex: 0xD2CDFF), opacity: 0.15)
        }
    }
}

extension View {
    /// インゴット（IDFA のカード・ロック画面の認証マーク台）の背景と影
    func ingotBackground(chamfer: CGFloat = 30, rimWidth: CGFloat = 8) -> some View {
        background {
            MetalSurface(chamfer: chamfer, rimWidth: rimWidth, rim: HeatTint.ingotRim) {
                IngotFace()
            }
            .shadow(color: .black.opacity(0.85), radius: 15, y: 26)
            .shadow(color: Color(hex: 0x5A50C8, opacity: 0.18), radius: 8)
        }
    }

    /// 一覧・設定のグループの背景と影
    func plateBackground(chamfer: CGFloat = 18) -> some View {
        background {
            MetalSurface(chamfer: chamfer, rimWidth: 1.5, rim: HeatTint.plateRim) {
                PlateFace()
            }
            .shadow(color: .black.opacity(0.8), radius: 12, y: 16)
        }
    }

    /// 小さなボタン台（ヘッダーのロック・設定・戻る）の背景
    func toolBackground(chamfer: CGFloat = 10) -> some View {
        background {
            MetalSurface(chamfer: chamfer, rimWidth: 1.5, rim: HeatTint.toolRim) {
                ZStack {
                    HeatTint.toolFace
                    HeatTint.streak(at: 0.46, color: Color(hex: 0xC8D2FF), opacity: 0.3)
                }
            }
            .shadow(color: .black.opacity(0.7), radius: 5, y: 6)
        }
    }
}

/// アプリ全体の背景。暗いベースに、左上と右下のにじみ光と、ぼかした光の玉を 2 つ置く
struct HeatTintBackground: View {
    var body: some View {
        ZStack {
            HeatTint.base
            RadialGradient(
                colors: [Color(hex: 0x161A36), Color(hex: 0x161A36, opacity: 0)],
                center: UnitPoint(x: 0.2, y: 0),
                startRadius: 0,
                endRadius: 420
            )
            RadialGradient(
                colors: [Color(hex: 0x0F1D33), Color(hex: 0x0F1D33, opacity: 0)],
                center: UnitPoint(x: 1, y: 1),
                startRadius: 0,
                endRadius: 380
            )
            GeometryReader { proxy in
                Circle()
                    .fill(Color(hex: 0x3B3F9A, opacity: 0.3))
                    .frame(width: 260, height: 260)
                    .blur(radius: 80)
                    .position(x: 50, y: proxy.size.height * 0.36)
                Circle()
                    .fill(Color(hex: 0x1F5A8F, opacity: 0.26))
                    .frame(width: 260, height: 260)
                    .blur(radius: 80)
                    .position(x: proxy.size.width - 40, y: proxy.size.height * 0.62)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
