//
//  PhoneHomeView.swift
//  IDFAVault
//
//  iPhone のホーム（デザインの Home / Denied）。大見出し「IDFA」、右上にロック・設定、この端末の IDFA のインゴット。
//  トラッキングが許可されていなければ、許可する 3 つの手順と「設定を開く」を出す。
//

import SwiftUI

struct PhoneHomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showsSettings = ScreenshotDemo.scene == .settings

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    OwnIdentifierCard()
                    if model.supportsOwnIdentifier, model.trackingStatus.isRefused {
                        TrackingDeniedSection()
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(HeatTintBackground())
            .hidesNavigationBar()
            .navigationDestination(isPresented: $showsSettings) {
                SettingsView()
            }
        }
        .copyFeedback(count: model.copyCount)
    }

    private var header: some View {
        HStack {
            Text(verbatim: "IDFA")
                .font(.system(size: 36, weight: .heavy))
                .tracking(2.2)
                .headingMetal()
                .accessibilityAddTraits(.isHeader)
            Spacer()
            HStack(spacing: 0) {
                Button {
                    model.lockNow()
                } label: {
                    ToolButtonLabel(systemImage: "lock")
                }
                .accessibilityLabel(Text("Lock Now"))
                .accessibilityIdentifier("lockNow")
                Groove(axis: .vertical, highlight: 0.32)
                    .padding(.vertical, 10)
                Button {
                    showsSettings = true
                } label: {
                    ToolButtonLabel(systemImage: "slider.horizontal.3")
                }
                .accessibilityLabel(Text("Settings"))
                .accessibilityIdentifier("settings")
            }
            .buttonStyle(.plain)
            .toolBackground()
        }
        .padding(.horizontal, 4)
    }
}

/// トラッキングが許可されていないときの、許可する手順と「設定を開く」（デザインの Denied）
struct TrackingDeniedSection: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "HOW TO ENABLE")
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                StepRow(number: 1, text: "Open “Privacy & Security” in the Settings app")
                Groove(highlight: 0.18)
                    .padding(.horizontal, 16)
                StepRow(number: 2, text: "In “Tracking”, turn on “Allow Apps to Request to Track”")
                Groove(highlight: 0.18)
                    .padding(.horizontal, 16)
                StepRow(number: 3, text: "Turn on “IDFA Vault” in the list")
            }
            .padding(.vertical, 4)
            .plateBackground()

            if let url = SystemSettings.appSettingsURL {
                Button {
                    openURL(url)
                } label: {
                    Text("Open Settings")
                        .font(.system(size: 17, weight: .bold))
                }
                .buttonStyle(.metalPrimary)
                .padding(.top, 8)
            }
            Text("You can still see the IDFA of your other devices.")
                .font(.caption)
                .foregroundStyle(HeatTint.tertiaryText)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
    }
}

/// 番号付きの手順の 1 行
private struct StepRow: View {
    var number: Int
    var text: LocalizedStringResource

    var body: some View {
        HStack(spacing: 14) {
            Text(verbatim: "\(number)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(HeatTint.ink)
                .frame(width: 30, height: 30)
                .background(ChamferedRect(chamfer: 8).fill(HeatTint.primaryFace))
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}
