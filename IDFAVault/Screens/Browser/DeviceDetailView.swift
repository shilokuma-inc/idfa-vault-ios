//
//  DeviceDetailView.swift
//  IDFAVault
//
//  サイドバーで選んだ端末の詳細（iPad・Mac）。許可状態のバッジ・端末名・IDFA のインゴット（コピー・共有・QR コード）・
//  OS・最終同期・認証（他の端末はトラッキング）を出す。
//

import SwiftUI

struct DeviceDetailView: View {
    @Environment(AppModel.self) private var model
    var selection: DeviceSelection
    var metrics: BrowserMetrics
    @State private var qrIdentifier: AdvertisingIdentifier?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                content
                Text("Your IDFA is stored only in your iCloud (private database). No one else, including the developer, can see it.")
                    .font(metrics.buttonFontSize < 16 ? .caption : .footnote)
                    .foregroundStyle(HeatTint.tertiaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 560, alignment: .leading)
            }
            .padding(metrics.detailPadding)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .refreshable {
            await model.refreshDevices()
        }
        .sheet(item: $qrIdentifier) { identifier in
            QRCodeSheet(identifier: identifier, deviceName: selectedName)
        }
    }

    @ViewBuilder private var content: some View {
        switch selection {
        case .own:
            ownContent
        case .other(let id):
            if let device = model.devices.otherDevices.first(where: { $0.id == id }) {
                otherContent(device)
            }
        }
    }

    private var selectedName: String {
        if case .other(let id) = selection, let device = model.devices.otherDevices.first(where: { $0.id == id }) {
            return device.name
        }
        return model.ownDeviceName ?? ""
    }

    // MARK: - この端末

    @ViewBuilder private var ownContent: some View {
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
        title(model.ownDeviceName ?? "")
        DetailIngot(
            deviceName: model.ownDeviceName ?? "",
            identifier: model.ownIdentifier,
            isMasked: false,
            metrics: metrics,
            unavailableMessage: ownUnavailableMessage,
            onToggleMask: nil
        ) { identifier in
            qrIdentifier = identifier
        }
        if model.supportsOwnIdentifier, model.trackingStatus.isRefused {
            TrackingDeniedSection()
                .frame(maxWidth: 560)
        }
        InfoTiles(items: [
            (title: "OS", value: Text(verbatim: DevicePlatform.current.rawValue)),
            (title: "Last Synced", value: relativeText(model.devices.lastSyncedAt)),
            (title: "Authentication", value: Text(model.biometry.methodName))
        ], metrics: metrics)
    }

    private var ownUnavailableMessage: LocalizedStringResource {
        if !model.supportsOwnIdentifier {
            #if os(macOS)
            // swiftlint:disable:next line_length
            return "macOS doesn't provide the advertising identifier (IDFA) to Mac apps. You can see and copy the IDFA of your iPhone and iPad in the sidebar."
            #else
            return "This platform doesn't provide the advertising identifier (IDFA) to apps."
            #endif
        }
        switch model.trackingStatus {
        case .notDetermined:
            return "Allow tracking to show this device's IDFA. It is only shown on screen and never used for advertising."
        case .authorized:
            return "This device returned an all-zero IDFA, so there is nothing to show."
        case .denied, .restricted:
            return "Tracking isn't allowed, so the system returns all zeros. To see your actual IDFA, allow tracking."
        }
    }

    // MARK: - 他の端末

    @ViewBuilder
    private func otherContent(_ device: DeviceRecord) -> some View {
        StatusBadge(
            title: device.trackingStatus.badgeTitle,
            color: device.trackingStatus.badgeColor,
            glows: device.trackingStatus == .authorized,
            fontSize: 13
        )
        title(device.name)
        DetailIngot(
            deviceName: device.name,
            identifier: device.identifier,
            isMasked: model.settings.masksOtherDevices && !model.devices.isRevealed(device),
            metrics: metrics,
            unavailableMessage: "Can't be retrieved because tracking isn't allowed",
            onToggleMask: model.settings.masksOtherDevices ? { model.devices.toggleReveal(device) } : nil
        ) { identifier in
            qrIdentifier = identifier
        }
        InfoTiles(items: [
            (title: "OS", value: Text(verbatim: device.platform.rawValue)),
            (title: "Last Synced", value: relativeText(device.updatedAt)),
            (title: "Tracking", value: Text(device.trackingStatus.allowsIdentifier ? "Allowed" : "Not Allowed"))
        ], metrics: metrics)
    }

    // MARK: - 部品

    private func title(_ name: String) -> some View {
        Text(verbatim: name)
            .font(.system(size: metrics.detailTitleSize, weight: .heavy))
            .tracking(metrics.detailTitleSize * 0.02)
            .headingMetal()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(.top, -6)
            .accessibilityAddTraits(.isHeader)
    }

    private func relativeText(_ date: Date?) -> Text {
        guard let date else {
            return Text(verbatim: "—")
        }
        return Text(date, format: .relative(presentation: .named, unitsStyle: .abbreviated))
    }
}

extension AdvertisingIdentifier: Identifiable {
    var id: String { value }
}

/// 詳細の IDFA のインゴット
private struct DetailIngot: View {
    @Environment(AppModel.self) private var model
    var deviceName: String
    var identifier: AdvertisingIdentifier?
    var isMasked: Bool
    var metrics: BrowserMetrics
    var unavailableMessage: LocalizedStringResource
    var onToggleMask: (() -> Void)?
    var onShowQRCode: (AdvertisingIdentifier) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.buttonFontSize < 16 ? 18 : 22) {
            Text(verbatim: "IDFA · \(deviceName.uppercased())")
                .font(.system(size: metrics.buttonFontSize < 16 ? 11 : 12, weight: .bold, design: .monospaced))
                .tracking(1.9)
                .foregroundStyle(HeatTint.text.opacity(0.78))
                .lineLimit(1)
            identifierView
                .padding(.top, -8)
            Groove(highlight: 0.3)
            if let identifier {
                buttons(identifier)
            } else {
                Text(unavailableMessage)
                    .font(metrics.buttonFontSize < 16 ? .callout : .body)
                    .foregroundStyle(identifier == nil && onToggleMask != nil ? HeatTint.warning : HeatTint.text.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, metrics.buttonFontSize < 16 ? 34 : 40)
        .padding(.vertical, metrics.buttonFontSize < 16 ? 28 : 34)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ingotBackground(chamfer: metrics.ingotChamfer, rimWidth: metrics.ingotRim)
    }

    @ViewBuilder private var identifierView: some View {
        let shown = identifier ?? .zero
        let text = IdentifierText(
            identifier: shown,
            isAvailable: identifier != nil,
            size: metrics.identifierSize
        )
        if isMasked, let identifier {
            Button {
                onToggleMask?()
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: identifier.masked)
                        .font(.system(size: metrics.identifierSize, weight: .bold, design: .monospaced))
                        .tracking(metrics.identifierSize * 0.03)
                        .identifierMetal()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("Tap to show all digits")
                        .font(.caption)
                        .foregroundStyle(HeatTint.tertiaryText)
                }
            }
            .buttonStyle(.plain)
        } else if let onToggleMask {
            Button(action: onToggleMask) {
                text
            }
            .buttonStyle(.plain)
        } else {
            text
        }
    }

    private func buttons(_ identifier: AdvertisingIdentifier) -> some View {
        HStack(spacing: metrics.buttonFontSize < 16 ? 10 : 12) {
            Button {
                model.copy(identifier)
            } label: {
                Text("Copy")
                    .font(.system(size: metrics.buttonFontSize, weight: .bold))
            }
            .buttonStyle(.metal(.primary, chamfer: 10, minHeight: metrics.buttonHeight, fillsWidth: false))
            ShareLink(item: identifier.value) {
                Text("Share")
                    .font(.system(size: metrics.buttonFontSize, weight: .bold))
            }
            .buttonStyle(.metal(.secondary, chamfer: 10, minHeight: metrics.buttonHeight, fillsWidth: false))
            Button {
                onShowQRCode(identifier)
            } label: {
                Text("QR Code")
                    .font(.system(size: metrics.buttonFontSize, weight: .bold))
            }
            .buttonStyle(.metal(.secondary, chamfer: 10, minHeight: metrics.buttonHeight, fillsWidth: false))
            #if os(macOS)
            Text("⌘C to copy")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(HeatTint.secondaryText)
                .padding(.leading, 8)
            #endif
        }
    }
}

/// OS・最終同期・認証などの小さな板（3 列）
private struct InfoTiles: View {
    var items: [(title: LocalizedStringResource, value: Text)]
    var metrics: BrowserMetrics

    var body: some View {
        HStack(spacing: metrics.buttonFontSize < 16 ? 14 : 16) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(metrics.buttonFontSize < 16 ? .caption : .footnote)
                        .foregroundStyle(HeatTint.secondaryText)
                    item.value
                        .font(.system(size: metrics.tileValueSize, weight: .semibold))
                        .foregroundStyle(HeatTint.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, metrics.buttonFontSize < 16 ? 18 : 22)
                .padding(.vertical, metrics.buttonFontSize < 16 ? 14 : 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .plateBackground(chamfer: 12)
                .accessibilityElement(children: .combine)
            }
        }
    }
}
