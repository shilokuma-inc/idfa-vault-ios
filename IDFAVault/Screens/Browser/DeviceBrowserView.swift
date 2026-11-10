//
//  DeviceBrowserView.swift
//  IDFAVault
//
//  iPad（横向き）と Mac のメインの画面（デザインの iPad / MacMain）。
//  左のサイドバーに端末の一覧、右に選んだ端末の IDFA のインゴット・コピー・共有・QR コードと、OS・最終同期・認証を出す。
//  iPhone の画面を引き伸ばさず、iPad は浮いたサイドバー、Mac はウインドウの左端のサイドバーにする。
//

import SwiftUI

/// iPad と Mac で変える寸法
struct BrowserMetrics {
    var sidebarWidth: CGFloat
    var floatsSidebar: Bool
    var showsSidebarHeader: Bool
    var iconSize: CGFloat
    var rowTitleSize: CGFloat
    var detailTitleSize: CGFloat
    var identifierSize: CGFloat
    var ingotChamfer: CGFloat
    var ingotRim: CGFloat
    var buttonHeight: CGFloat
    var buttonFontSize: CGFloat
    var tileValueSize: CGFloat
    var detailPadding: EdgeInsets

    static let pad = BrowserMetrics(
        sidebarWidth: 320,
        floatsSidebar: true,
        showsSidebarHeader: true,
        iconSize: 38,
        rowTitleSize: 16,
        detailTitleSize: 46,
        identifierSize: 30,
        ingotChamfer: 40,
        ingotRim: 10,
        buttonHeight: 47,
        buttonFontSize: 16,
        tileValueSize: 18,
        detailPadding: EdgeInsets(top: 60, leading: 32, bottom: 28, trailing: 56)
    )

    static let mac = BrowserMetrics(
        sidebarWidth: 260,
        floatsSidebar: false,
        showsSidebarHeader: false,
        iconSize: 30,
        rowTitleSize: 13,
        detailTitleSize: 38,
        identifierSize: 27,
        ingotChamfer: 36,
        ingotRim: 9,
        buttonHeight: 37,
        buttonFontSize: 13,
        tileValueSize: 16,
        detailPadding: EdgeInsets(top: 44, leading: 52, bottom: 44, trailing: 52)
    )

    static var current: BrowserMetrics {
        #if os(macOS)
        .mac
        #else
        .pad
        #endif
    }
}

/// サイドバーで選んでいる端末
enum DeviceSelection: Hashable {
    case own
    case other(String)
}

struct DeviceBrowserView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: DeviceSelection = .own
    @State private var showsSettings = ScreenshotDemo.scene == .settings
    var metrics: BrowserMetrics = .current

    var body: some View {
        HStack(spacing: metrics.floatsSidebar ? 32 : 0) {
            DeviceSidebar(selection: $selection, showsSettings: $showsSettings, metrics: metrics)
            DeviceDetailView(selection: resolvedSelection, metrics: metrics)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(metrics.floatsSidebar ? EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 0) : EdgeInsets())
        .background(HeatTintBackground())
        .copyFeedback(count: model.copyCount)
        .focusedSceneValue(\.copyableIdentifier, copyableIdentifier)
        .sheet(isPresented: $showsSettings) {
            SettingsSheet()
        }
    }

    /// 選んでいた端末が一覧から消えたら（すべて削除など）、この端末に戻す
    private var resolvedSelection: DeviceSelection {
        if case .other(let id) = selection, !model.devices.otherDevices.contains(where: { $0.id == id }) {
            return .own
        }
        return selection
    }

    /// ⌘C でコピーする IDFA（Mac）
    private var copyableIdentifier: AdvertisingIdentifier? {
        switch resolvedSelection {
        case .own:
            model.ownIdentifier
        case .other(let id):
            model.devices.otherDevices.first { $0.id == id }?.identifier
        }
    }
}

// MARK: - サイドバー

private struct DeviceSidebar: View {
    private static let floatingPadding = EdgeInsets(top: 26, leading: 14, bottom: 22, trailing: 14)
    private static let attachedPadding = EdgeInsets(top: 20, leading: 12, bottom: 20, trailing: 12)

    @Environment(AppModel.self) private var model
    @Binding var selection: DeviceSelection
    @Binding var showsSettings: Bool
    var metrics: BrowserMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if metrics.showsSidebarHeader {
                header
                    .padding(.leading, 10)
                    .padding(.trailing, 6)
                    .padding(.bottom, 16)
            }
            SidebarLabel(title: DeviceKind.current == .mac ? "THIS MAC" : "THIS DEVICE", metrics: metrics)
            SidebarRow(
                title: model.ownDeviceName ?? "",
                symbolName: DeviceKind.current.symbolName,
                detail: ownDetail,
                isSelected: selection == .own,
                metrics: metrics
            ) {
                selection = .own
            }
            SidebarLabel(title: "SAME APPLE ID", metrics: metrics)
                .padding(.top, 16)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(model.devices.otherDevices) { device in
                        SidebarRow(
                            title: device.name,
                            symbolName: device.platform.kind.symbolName,
                            detail: device.identifier.map { .identifier($0.shortMasked) } ?? .notAllowed,
                            isSelected: selection == .other(device.id),
                            metrics: metrics
                        ) {
                            selection = .other(device.id)
                        }
                    }
                    if model.devices.otherDevices.isEmpty {
                        Text(emptyMessage)
                            .font(.caption)
                            .foregroundStyle(HeatTint.tertiaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 10)
                            .padding(.top, 4)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            Spacer(minLength: 8)
            LastSyncedLabel(date: model.devices.lastSyncedAt, prefersSyncedWording: true)
                .font(.caption)
                .foregroundStyle(HeatTint.tertiaryText)
                .padding(.horizontal, 10)
        }
        .padding(metrics.floatsSidebar ? Self.floatingPadding : Self.attachedPadding)
        .frame(width: metrics.sidebarWidth)
        .frame(maxHeight: .infinity)
        .background {
            if metrics.floatsSidebar {
                MetalSurface(chamfer: 22, rimWidth: 1.5, rim: HeatTint.plateRim) {
                    PlateFace()
                }
                .shadow(color: .black.opacity(0.8), radius: 20, y: 24)
            } else {
                HStack(spacing: 0) {
                    HeatTint.plateFace
                    Groove(axis: .vertical, highlight: 0.2)
                }
                .ignoresSafeArea()
            }
        }
    }

    private var header: some View {
        HStack {
            Text(verbatim: "IDFA")
                .font(.system(size: 34, weight: .heavy))
                .tracking(2)
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

    private var ownDetail: SidebarRow.Detail {
        if let identifier = model.ownIdentifier {
            return .identifier(identifier.shortMasked)
        }
        return model.supportsOwnIdentifier ? .notAllowed : .unavailable
    }

    private var emptyMessage: LocalizedStringResource {
        model.devices.status == .noAccount
            ? "Sign in to iCloud to see the IDFA of your other devices."
            : "No other devices yet. Open IDFA Vault on your other devices signed in with the same Apple ID."
    }
}

private struct SidebarLabel: View {
    var title: String
    var metrics: BrowserMetrics

    var body: some View {
        Text(verbatim: title)
            .font(.system(size: metrics.rowTitleSize < 16 ? 11 : 12, weight: .bold, design: .monospaced))
            .tracking(1.6)
            .foregroundStyle(HeatTint.sectionHeader)
            .padding(.horizontal, 10)
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct SidebarRow: View {
    enum Detail {
        case identifier(String)
        case notAllowed
        case unavailable
    }

    var title: String
    var symbolName: String
    var detail: Detail
    var isSelected: Bool
    var metrics: BrowserMetrics
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: metrics.iconSize > 32 ? 12 : 10) {
                IconPlate(systemImage: symbolName, size: metrics.iconSize, isHighlighted: isSelected)
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: title)
                        .font(.system(size: metrics.rowTitleSize, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(HeatTint.text)
                        .lineLimit(1)
                    detailText
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, metrics.iconSize > 32 ? 12 : 10)
            .padding(.vertical, metrics.iconSize > 32 ? 10 : 8)
            .background {
                if isSelected {
                    MetalSurface(chamfer: 12, rimWidth: 1.5, rim: HeatTint.selectedRowRim) {
                        ZStack {
                            HeatTint.selectedRowFace
                            HeatTint.streak(at: 0.26, width: 0.12, opacity: 0.3)
                        }
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder private var detailText: some View {
        let size: CGFloat = metrics.rowTitleSize < 16 ? 11 : 12
        switch detail {
        case .identifier(let masked):
            Text(verbatim: masked)
                .font(.system(size: size, design: .monospaced))
                .foregroundStyle(HeatTint.secondaryText)
        case .notAllowed:
            Text("Not Allowed")
                .font(.system(size: size))
                .foregroundStyle(HeatTint.warning)
        case .unavailable:
            Text("Not Available")
                .font(.system(size: size))
                .foregroundStyle(HeatTint.tertiaryText)
        }
    }
}

// MARK: - ⌘C

struct CopyableIdentifierKey: FocusedValueKey {
    typealias Value = AdvertisingIdentifier
}

extension FocusedValues {
    /// メインのウインドウで選んでいる端末の IDFA（Mac の ⌘C）
    var copyableIdentifier: AdvertisingIdentifier? {
        get { self[CopyableIdentifierKey.self] }
        set { self[CopyableIdentifierKey.self] = newValue }
    }
}
