//
//  OtherDevicesSection.swift
//  IDFAVault
//
//  同じ Apple ID の他の端末の一覧（デザインの Home の SAME APPLE ID）。
//  IDFA は初期設定で伏せ字にし、タップで全桁と切り替える。未許可の端末はオレンジで理由を出す（仕様書 3.4）。
//

import SwiftUI

struct OtherDevicesSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "SAME APPLE ID") {
                LastSyncedLabel(date: model.devices.lastSyncedAt)
            }
            .padding(.horizontal, 4)
            .padding(.top, 8)

            content

            Text("Your IDFA is stored only in your iCloud (private database). No one else, including the developer, can see it.")
                .font(.caption)
                .foregroundStyle(HeatTint.tertiaryText)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        }
    }

    @ViewBuilder private var content: some View {
        let devices = model.devices
        if devices.status == .noAccount {
            SyncMessagePlate(systemImage: "icloud.slash", text: "Sign in to iCloud to see the IDFA of your other devices.")
        } else if devices.otherDevices.isEmpty {
            switch devices.status {
            case .idle:
                SyncMessagePlate(systemImage: "icloud", text: "Syncing with iCloud…", showsProgress: true)
            case .failed:
                SyncMessagePlate(systemImage: "exclamationmark.icloud", text: "Couldn't sync with iCloud. Pull down to try again.")
            case .synced, .noAccount:
                SyncMessagePlate(
                    systemImage: "icloud",
                    text: "No other devices yet. Open IDFA Vault on your other devices signed in with the same Apple ID."
                )
            }
        } else {
            DeviceListPlate(devices: devices.otherDevices)
        }
    }
}

/// 「iCloud · 2 分前」。相対時刻なので、30 秒ごとに書き直す
struct LastSyncedLabel: View {
    var date: Date?
    var prefersSyncedWording = false

    var body: some View {
        if let date {
            TimelineView(.periodic(from: .now, by: 30)) { _ in
                let relative = date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
                if prefersSyncedWording {
                    Text("iCloud · Synced \(relative)")
                } else {
                    Text("iCloud · \(relative)")
                }
            }
        }
    }
}

/// 他の端末の一覧の板
struct DeviceListPlate: View {
    var devices: [DeviceRecord]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(devices.enumerated()), id: \.element.id) { index, device in
                if index > 0 {
                    Groove(highlight: 0.18)
                        .padding(.horizontal, 16)
                }
                DeviceRow(device: device)
            }
        }
        .plateBackground()
    }
}

/// 他の端末の 1 行。名前と IDFA（伏せ字か全桁）、コピーのボタン
struct DeviceRow: View {
    @Environment(AppModel.self) private var model
    var device: DeviceRecord

    var body: some View {
        HStack(spacing: 12) {
            IconPlate(systemImage: device.platform.kind.symbolName, isDimmed: device.identifier == nil)
            if let identifier = device.identifier {
                Button {
                    model.devices.toggleReveal(device)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        name
                        OtherDeviceIdentifier(identifier: identifier, isMasked: isMasked)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text(isMasked ? "Shows all digits" : "Hides the middle digits"))
                Button {
                    model.copy(identifier)
                } label: {
                    Image(systemName: "square.on.square")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(HeatTint.link)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Copy the IDFA of \(device.name)"))
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    name
                    Text("Can't be retrieved because tracking isn't allowed")
                        .font(.footnote)
                        .foregroundStyle(HeatTint.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, device.identifier == nil ? 16 : 10)
        .padding(.vertical, 12)
    }

    private var isMasked: Bool {
        model.settings.masksOtherDevices && !model.devices.isRevealed(device)
    }

    private var name: some View {
        Text(verbatim: device.name)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(HeatTint.text)
            .lineLimit(1)
    }
}

/// 他の端末の IDFA。全桁が 1 行に入らなければ 2 行に分ける
struct OtherDeviceIdentifier: View {
    var identifier: AdvertisingIdentifier
    var isMasked: Bool
    var size: CGFloat = 13

    var body: some View {
        Group {
            if isMasked {
                Text(verbatim: identifier.masked)
            } else {
                ViewThatFits(in: .horizontal) {
                    Text(verbatim: identifier.value)
                    Text(verbatim: "\(identifier.twoLines.first)\n\(identifier.twoLines.second)")
                }
            }
        }
        .font(.system(size: size, design: .monospaced))
        .foregroundStyle(HeatTint.secondaryText)
        .accessibilityLabel(Text(verbatim: isMasked ? identifier.masked : identifier.value))
        .accessibilityIdentifier("otherIdentifier")
    }
}

/// 一覧の代わりに出す案内（iCloud にサインインしていない・まだ端末が無いなど）
struct SyncMessagePlate: View {
    var systemImage: String
    var text: LocalizedStringResource
    var showsProgress = false

    var body: some View {
        HStack(spacing: 12) {
            IconPlate(systemImage: systemImage)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(HeatTint.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if showsProgress {
                ProgressView()
                    .tint(HeatTint.secondaryText)
            }
        }
        .padding(16)
        .plateBackground()
        .accessibilityElement(children: .combine)
    }
}
