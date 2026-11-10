//
//  MenuBarContent.swift
//  IDFAVault
//
//  macOS のメニューバー（デザインの MacMenuBar。MenuBarExtra）。開くたびに本人確認をし、解除しているあいだだけ値を出す。
//  このMacの IDFA とコピー、他の端末（伏せ字＋コピー）、「ウインドウを開く」「今すぐロック」。
//

#if os(macOS)
import SwiftUI

struct MenuBarContent: View {
    static let mainWindowID = "main"

    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @State private var isUnlocked = false
    @State private var isAuthenticating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(verbatim: "IDFA Vault")
                    .font(.system(size: 14, weight: .heavy))
                    .tracking(0.5)
                    .headingMetal()
                Spacer()
                if isUnlocked {
                    LastSyncedLabel(date: model.devices.lastSyncedAt)
                        .font(.system(size: 11))
                        .foregroundStyle(HeatTint.tertiaryText)
                }
            }
            .padding(.horizontal, 2)
            if isUnlocked {
                unlockedContent
            } else {
                lockedContent
            }
        }
        .padding(14)
        .frame(width: 340)
        .background {
            MetalSurface(chamfer: 14, rimWidth: 1.5, rim: HeatTint.plateRim) {
                PlateFace()
            }
        }
        .foregroundStyle(HeatTint.text)
        .preferredColorScheme(.dark)
        .copyFeedback(count: model.copyCount)
        .macWindowBehavior(model: model, observesActivation: false)
        .task {
            await authenticate()
        }
        .onDisappear {
            // 閉じたら、次に開いたときにまた本人確認をする
            isUnlocked = false
            model.devices.concealAll()
        }
    }

    // MARK: - ロック中

    private var lockedContent: some View {
        VStack(spacing: 12) {
            Image(systemName: model.biometry.symbolName)
                .font(.system(size: 34, weight: .light))
                .identifierMetal()
                .frame(width: 72, height: 72)
                .ingotBackground(chamfer: 20, rimWidth: 5)
                .padding(.top, 6)
            if isAuthenticating, let message = model.biometry.authenticatingMessage {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(HeatTint.secondaryText)
            }
            Button {
                Task { await authenticate() }
            } label: {
                Text(model.biometry.unlockTitle)
                    .font(.system(size: 13, weight: .bold))
            }
            .buttonStyle(.metal(.primary, chamfer: 8, minHeight: 31))
            .disabled(isAuthenticating)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }

    private func authenticate() async {
        guard !isUnlocked, !isAuthenticating else {
            return
        }
        isAuthenticating = true
        isUnlocked = await model.authenticateForMenuBar()
        isAuthenticating = false
    }

    // MARK: - 解除中

    /// この Mac の IDFA の板（自分の IDFA を取れるときだけ）
    @ViewBuilder private var ownIngot: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "THIS MAC")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(HeatTint.text.opacity(0.78))
            IdentifierText(identifier: model.displayedIdentifier, isAvailable: model.ownIdentifier != nil, size: 13)
            if let identifier = model.ownIdentifier {
                Button {
                    model.copy(identifier)
                } label: {
                    Text("Copy")
                        .font(.system(size: 13, weight: .bold))
                }
                .buttonStyle(.metal(.primary, chamfer: 8, minHeight: 31))
            } else {
                Text(model.trackingStatus.badgeTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(model.trackingStatus.badgeColor)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ingotBackground(chamfer: 14, rimWidth: 5)
    }

    @ViewBuilder private var unlockedContent: some View {
        if model.supportsOwnIdentifier {
            ownIngot
        } else {
            // Mac は自分の IDFA を取れないので、iPhone・iPad の IDFA だけを出す
            Text("macOS doesn't provide the IDFA to Mac apps.")
                .font(.system(size: 11))
                .foregroundStyle(HeatTint.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        }

        Text(verbatim: "SAME APPLE ID")
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(1.4)
            .foregroundStyle(HeatTint.sectionHeader)
            .padding(.horizontal, 2)
            .padding(.top, 4)

        if model.devices.otherDevices.isEmpty {
            Text(emptyMessage)
                .font(.system(size: 11))
                .foregroundStyle(HeatTint.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        } else {
            ForEach(Array(model.devices.otherDevices.enumerated()), id: \.element.id) { index, device in
                if index > 0 {
                    Groove(highlight: 0.18)
                }
                menuRow(device)
            }
        }

        Groove(highlight: 0.18)
        HStack {
            Button {
                openWindow(id: Self.mainWindowID)
                NSApplication.shared.activate()
            } label: {
                Text("Open Window")
            }
            Spacer()
            Button {
                model.lockNow()
                isUnlocked = false
            } label: {
                Text("Lock Now")
            }
        }
        .buttonStyle(.plain)
        .font(.system(size: 12))
        .foregroundStyle(HeatTint.text.opacity(0.8))
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    private var emptyMessage: LocalizedStringResource {
        if model.devices.status == .noAccount {
            return "Sign in to iCloud to see the IDFA of your other devices."
        }
        return model.supportsOwnIdentifier
            ? "No other devices yet. Open IDFA Vault on your other devices signed in with the same Apple ID."
            : "No iPhone or iPad yet. Open IDFA Vault on your iPhone or iPad signed in with the same Apple ID."
    }

    private func menuRow(_ device: DeviceRecord) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: device.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                if let identifier = device.identifier {
                    // メニューバーでは、設定にかかわらず伏せ字にする（コピーは全桁）
                    Text(verbatim: identifier.masked)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(HeatTint.secondaryText)
                } else {
                    Text("Not Allowed")
                        .font(.system(size: 11))
                        .foregroundStyle(HeatTint.warning)
                }
            }
            Spacer()
            if let identifier = device.identifier {
                Button {
                    model.copy(identifier)
                } label: {
                    Text("Copy")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(HeatTint.link)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Copy the IDFA of \(device.name)"))
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
    }
}
#endif
