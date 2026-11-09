//
//  VisionMainView.swift
//  IDFAVault
//
//  visionOS のメインのウインドウ（デザインの Vision）。面取りの暗い金属の板に、この端末の IDFA と、同じ Apple ID の他の端末を出す。
//  visionOS の SDK には AdSupport が無く、visionOS のアプリはこの端末の IDFA を取得できないので、その旨を出す。
//  ウインドウはガラスの背景を使わず（windowStyle(.plain)）、板の形で角丸を避ける。
//

import SwiftUI

#if os(visionOS)

struct VisionMainView: View {
    @Environment(AppModel.self) private var model
    @State private var showsSettings = ScreenshotDemo.scene == .settings
    @State private var qrDevice: DeviceRecord?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                Text(verbatim: model.ownDeviceName ?? "Apple Vision Pro")
                    .font(.system(size: 36, weight: .heavy))
                    .tracking(0.7)
                    .headingMetal()
                    .padding(.top, -4)
                    .accessibilityAddTraits(.isHeader)
                ownIngot
                SectionHeader(title: "SAME APPLE ID") {
                    LastSyncedLabel(date: model.devices.lastSyncedAt)
                }
                .padding(.top, 6)
                otherDevices
            }
            .padding(.horizontal, 44)
            .padding(.vertical, 36)
        }
        .scrollBounceBehavior(.basedOnSize)
        .refreshable {
            await model.refreshDevices()
        }
        .background {
            VisionPanelBackground()
        }
        .copyFeedback(count: model.copyCount)
        .sheet(isPresented: $showsSettings) {
            SettingsSheet()
                .frame(minWidth: 560, minHeight: 640)
        }
        .sheet(item: $qrDevice) { device in
            if let identifier = device.identifier {
                QRCodeSheet(identifier: identifier, deviceName: device.name)
            }
        }
    }

    private var header: some View {
        HStack {
            if model.supportsOwnIdentifier {
                StatusBadge(
                    title: model.trackingStatus.badgeTitle,
                    color: model.trackingStatus.badgeColor,
                    glows: model.trackingStatus == .authorized,
                    fontSize: 13
                )
            } else {
                StatusBadge(title: "Not Available", color: HeatTint.sectionHeader, fontSize: 13)
            }
            Spacer()
            HStack(spacing: 0) {
                Button {
                    model.lockNow()
                } label: {
                    ToolButtonLabel(systemImage: "lock")
                }
                .accessibilityLabel(Text("Lock Now"))
                Groove(axis: .vertical, highlight: 0.32)
                    .padding(.vertical, 10)
                Button {
                    showsSettings = true
                } label: {
                    ToolButtonLabel(systemImage: "slider.horizontal.3")
                }
                .accessibilityLabel(Text("Settings"))
            }
            .buttonStyle(.plain)
            .fixedSize()
            .toolBackground()
        }
    }

    /// この端末の IDFA の板（visionOS では取得できない旨）
    @ViewBuilder private var ownIngot: some View {
        HStack(spacing: 20) {
            if let identifier = model.ownIdentifier {
                IdentifierText(identifier: identifier, isAvailable: true, size: 22)
                Spacer(minLength: 0)
                CopyButton(identifier: identifier, minHeight: 53, fillsWidth: false)
            } else {
                // swiftlint:disable:next line_length
                Text("visionOS doesn't provide the advertising identifier (IDFA) to visionOS apps. You can see and copy the IDFA of your other devices below.")
                    .font(.callout)
                    .foregroundStyle(HeatTint.text.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.leading, 26)
        .padding(.trailing, 18)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ingotBackground(chamfer: 24, rimWidth: 6)
    }

    @ViewBuilder private var otherDevices: some View {
        let devices = model.devices
        if devices.status == .noAccount {
            SyncMessagePlate(systemImage: "icloud.slash", text: "Sign in to iCloud to see the IDFA of your other devices.")
        } else if devices.otherDevices.isEmpty {
            SyncMessagePlate(
                systemImage: "icloud",
                text: "No other devices yet. Open IDFA Vault on your other devices signed in with the same Apple ID.",
                showsProgress: devices.status == .idle
            )
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                ForEach(devices.otherDevices) { device in
                    VisionDeviceCard(device: device) {
                        qrDevice = device
                    }
                }
            }
        }
    }
}

/// 他の端末の板。タップで伏せ字と全桁を切り替え、コピーと QR コードのボタンを置く
private struct VisionDeviceCard: View {
    @Environment(AppModel.self) private var model
    var device: DeviceRecord
    var onShowQRCode: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                model.devices.toggleReveal(device)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: device.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(HeatTint.text)
                        .lineLimit(1)
                    if let identifier = device.identifier {
                        OtherDeviceIdentifier(
                            identifier: identifier,
                            isMasked: model.settings.masksOtherDevices && !model.devices.isRevealed(device)
                        )
                    } else {
                        Text("Can't be retrieved because tracking isn't allowed")
                            .font(.footnote)
                            .foregroundStyle(HeatTint.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(device.identifier == nil)
            if let identifier = device.identifier {
                iconButton("square.on.square", label: Text("Copy the IDFA of \(device.name)")) {
                    model.copy(identifier)
                }
                iconButton("qrcode", label: Text("QR Code")) {
                    onShowQRCode()
                }
            }
        }
        .padding(.leading, 22)
        .padding(.trailing, 12)
        .padding(.vertical, 12)
        .plateBackground(chamfer: 14)
    }

    private func iconButton(_ systemImage: String, label: Text, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(HeatTint.link)
                .frame(width: 44, height: 44)
                .contentShape(.hoverEffect, ChamferedRect(chamfer: 10))
        }
        .buttonStyle(.plain)
        .hoverEffect()
        .accessibilityLabel(label)
    }
}

#endif

/// visionOS のウインドウの板（ガラスの代わりに、面取りの暗い金属）。ほかのプラットフォームでも作れるようにしておく
struct VisionPanelBackground: View {
    var chamfer: CGFloat = 44

    var body: some View {
        MetalSurface(chamfer: chamfer, rimWidth: 2, rim: HeatTint.plateRim) {
            ZStack {
                HeatTint.base
                HeatTintBackground()
                HeatTint.streak(at: 0.3, color: Color(hex: 0xD2CDFF), opacity: 0.12)
            }
        }
    }
}
