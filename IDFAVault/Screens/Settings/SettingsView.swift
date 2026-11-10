//
//  SettingsView.swift
//  IDFAVault
//
//  設定（デザインの Settings）。SECURITY / DISPLAY のグループ（ICLOUD は同期を入れるときに足す）。
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    dismiss()
                } label: {
                    ToolButtonLabel(systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                .toolBackground()
                .accessibilityLabel(Text("Back"))

                Text("Settings")
                    .font(.system(size: 34, weight: .heavy))
                    .tracking(1.36)
                    .headingMetal()
                    .padding(.horizontal, 4)
                    .padding(.top, 6)
                    .padding(.bottom, 8)
                    .accessibilityAddTraits(.isHeader)

                SettingsForm()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(HeatTintBackground())
        .hidesNavigationBar()
    }
}

/// 設定の項目。iPhone の設定画面と、iPad・Mac の設定（シート・ウインドウ）で共通に使う
struct SettingsForm: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "SECURITY")
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                Toggle(isOn: .constant(true)) {
                    SettingLabel(title: model.biometry.requireAtLaunchTitle, detail: "Can't be turned off")
                }
                .toggleStyle(.chamfer)
                .disabled(true)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                SettingsDivider()
                autoLockRow
            }
            .plateBackground(chamfer: 16)

            SectionHeader(title: "DISPLAY")
                .padding(.horizontal, 4)
                .padding(.top, 8)
            VStack(spacing: 0) {
                Toggle(isOn: $settings.hidesWhileCapturing) {
                    SettingLabel(title: "Hide During Screen Recording or Mirroring")
                }
                .toggleStyle(.chamfer)
                .padding(.horizontal, 16)
                .frame(minHeight: 54)
                .accessibilityIdentifier("hidesWhileCapturing")
            }
            .plateBackground(chamfer: 16)

            Text("Each device has its own IDFA, and it changes if you reset it.")
                .font(.caption)
                .foregroundStyle(HeatTint.tertiaryText)
                .lineSpacing(3)
                .padding(.horizontal, 4)
        }
    }

    private var autoLockRow: some View {
        @Bindable var settings = model.settings
        return Menu {
            Picker(selection: $settings.autoLock) {
                ForEach(AutoLockTiming.allCases) { timing in
                    Text(timing.title)
                        .tag(timing)
                }
            } label: {
                Text("Auto-Lock")
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 8) {
                Text("Auto-Lock")
                    .font(.callout)
                    .foregroundStyle(HeatTint.text)
                Spacer(minLength: 8)
                Text(model.settings.autoLock.title)
                    .font(.callout)
                    .foregroundStyle(HeatTint.secondaryText)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(HeatTint.sectionHeader)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityIdentifier("autoLock")
    }
}

/// 設定の項目名と補足
struct SettingLabel: View {
    var title: LocalizedStringResource
    var detail: LocalizedStringResource?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.callout)
                .foregroundStyle(HeatTint.text)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(HeatTint.tertiaryText)
            }
        }
    }
}

/// 設定のグループの中の区切り
struct SettingsDivider: View {
    var body: some View {
        Groove(highlight: 0.18)
            .padding(.horizontal, 16)
    }
}
