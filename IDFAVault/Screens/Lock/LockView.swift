//
//  LockView.swift
//  IDFAVault
//
//  ロック画面（デザインの Main / LockTouchID）。八角形のインゴットに認証のマーク（SF Symbol）を刻み、
//  認証方式に合わせた解除ボタンと、パスコード（Mac はパスワード）のボタンを出す。
//

import SwiftUI

struct LockView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    LockHeading()
                    Spacer(minLength: 28)
                        .frame(maxHeight: 60)
                    BiometryPlate(symbolName: model.biometry.symbolName, size: 184, chamfer: 54, rimWidth: 9)
                    statusText
                        .padding(.top, 24)
                    Spacer(minLength: 28)
                    buttons
                    Text(model.settings.autoLock.lockFootnote)
                        .font(.caption)
                        .foregroundStyle(HeatTint.tertiaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 18)
                }
                .padding(.horizontal, 24)
                .padding(.top, proxy.size.height > 700 ? 48 : 20)
                .padding(.bottom, 24)
                .frame(maxWidth: 440)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    /// 認証中の補足と、失敗したときの案内。高さを確保して、文言が変わってもボタンが動かないようにする
    private var statusText: some View {
        Group {
            if model.isAuthenticating, let message = model.biometry.authenticatingMessage {
                Text(message)
            } else if model.lastAuthenticationOutcome == .unavailable {
                Text("Set a passcode on this device to unlock IDFA Vault.")
            } else if model.lastAuthenticationOutcome == .failed {
                Text("Couldn't verify your identity. Try again.")
            } else {
                Text(verbatim: " ")
                    .accessibilityHidden(true)
            }
        }
        .font(.subheadline)
        .foregroundStyle(HeatTint.secondaryText)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(minHeight: 40, alignment: .top)
    }

    private var buttons: some View {
        VStack(spacing: 12) {
            Button {
                Task { await model.unlock() }
            } label: {
                Text(model.biometry.unlockTitle)
                    .font(.system(size: 17, weight: .bold))
            }
            .buttonStyle(.metalPrimary)
            .accessibilityIdentifier("unlock")

            Button {
                Task { await model.unlock() }
            } label: {
                Text(BiometryKind.passcodeButtonTitle)
                    .font(.system(size: 15, weight: .semibold))
            }
            .buttonStyle(.metal(.secondary, chamfer: 10, minHeight: 45, alignment: .leading))
        }
        .disabled(model.isAuthenticating)
    }
}

/// ロック画面の見出し（LOCKED・アプリ名・説明）
struct LockHeading: View {
    var titleSize: CGFloat = 34

    var body: some View {
        VStack(spacing: 0) {
            Text(verbatim: "LOCKED")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .tracking(2.9)
                .foregroundStyle(HeatTint.secondaryText)
            Text(verbatim: "IDFA Vault")
                .font(.system(size: titleSize, weight: .heavy))
                .tracking(titleSize * 0.04)
                .headingMetal()
                .padding(.top, 12)
                .accessibilityAddTraits(.isHeader)
            Text("Verify your identity to show your advertising identifier")
                .font(.subheadline)
                .foregroundStyle(HeatTint.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
        }
    }
}

/// 認証のマークを刻んだ八角形のインゴット
struct BiometryPlate: View {
    var symbolName: String
    var size: CGFloat
    var chamfer: CGFloat
    var rimWidth: CGFloat

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: size * 0.4, weight: .light))
            .identifierMetal()
            .frame(width: size, height: size)
            .ingotBackground(chamfer: chamfer, rimWidth: rimWidth)
            .accessibilityHidden(true)
    }
}
