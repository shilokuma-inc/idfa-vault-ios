//
//  IdentifierViews.swift
//  IDFAVault
//
//  IDFA の値の文字と、この端末の IDFA のインゴット（カード）。
//

import SwiftUI

/// IDFA の値。取得できるときは金属の文字、取得できないとき（全桁 0）は薄く出す
struct IdentifierText: View {
    var identifier: AdvertisingIdentifier
    var isAvailable: Bool
    var size: CGFloat = 21
    /// iPhone のように 2 行に分けるか（`6D92078A-8246-4BA4-` / `AE5B-76104861E7DC`）
    var splitsIntoTwoLines = false

    var body: some View {
        let lines = identifier.twoLines
        Text(verbatim: splitsIntoTwoLines ? "\(lines.first)\n\(lines.second)" : identifier.value)
            .font(.system(size: size, weight: .bold, design: .monospaced))
            .tracking(size * 0.04)
            .lineSpacing(size * 0.3)
            .lineLimit(splitsIntoTwoLines ? 2 : 1)
            .minimumScaleFactor(0.6)
            .modifier(IdentifierStyle(isAvailable: isAvailable))
            .accessibilityLabel(Text(verbatim: identifier.value))
    }
}

private struct IdentifierStyle: ViewModifier {
    var isAvailable: Bool

    func body(content: Content) -> some View {
        if isAvailable {
            content.identifierMetal()
        } else {
            content.foregroundStyle(HeatTint.secondaryText.opacity(0.7))
        }
    }
}

/// この端末の IDFA のインゴット（iPhone のホーム）。許可状態に合わせて、コピー・共有か説明を出す
struct OwnIdentifierCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 狭い iPhone（SE など）や長い言語では 1 行に入らないので、バッジを切らずに上の行に回す
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    heading
                    Spacer(minLength: 8)
                    badge
                }
                VStack(alignment: .leading, spacing: 10) {
                    badge
                    heading
                }
            }
            IdentifierText(
                identifier: model.displayedIdentifier,
                isAvailable: model.ownIdentifier != nil,
                splitsIntoTwoLines: true
            )
            .accessibilityIdentifier("ownIdentifier")
            Groove(highlight: 0.3)
            detail
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ingotBackground()
    }

    private var heading: some View {
        Text(verbatim: "IDFA · \(DeviceKind.current.engravedName)")
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .tracking(1.9)
            .foregroundStyle(HeatTint.text.opacity(0.78))
            .lineLimit(1)
            .fixedSize()
    }

    @ViewBuilder private var badge: some View {
        if model.supportsOwnIdentifier {
            StatusBadge(
                title: model.trackingStatus.badgeTitle,
                color: model.trackingStatus.badgeColor,
                glows: model.trackingStatus == .authorized
            )
            .fixedSize()
        } else {
            StatusBadge(title: "Not Available", color: HeatTint.sectionHeader)
                .fixedSize()
        }
    }

    @ViewBuilder private var detail: some View {
        if let identifier = model.ownIdentifier {
            HStack(spacing: 10) {
                CopyButton(identifier: identifier)
                ShareIdentifierButton(identifier: identifier)
            }
            Text("Copied values are cleared from the clipboard after 60 seconds")
                .font(.caption)
                .foregroundStyle(HeatTint.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        } else if !model.supportsOwnIdentifier {
            Text("This platform doesn't provide the advertising identifier (IDFA) to apps.")
                .font(.subheadline)
                .foregroundStyle(HeatTint.text.opacity(0.9))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            switch model.trackingStatus {
            case .denied, .restricted:
                Text("Tracking isn't allowed, so the system returns all zeros. To see your actual IDFA, allow tracking.")
                    .font(.subheadline)
                    .foregroundStyle(HeatTint.text.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .notDetermined:
                Text("Allow tracking to show this device's IDFA. It is only shown on screen and never used for advertising.")
                    .font(.subheadline)
                    .foregroundStyle(HeatTint.text.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    Task { await model.requestTrackingIfNeeded() }
                } label: {
                    Text("Allow Tracking")
                        .font(.system(size: 16, weight: .bold))
                }
                .buttonStyle(.metal(.primary, chamfer: 10, minHeight: 47))
            case .authorized:
                Text("This device returned an all-zero IDFA, so there is nothing to show.")
                    .font(.subheadline)
                    .foregroundStyle(HeatTint.text.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// IDFA をコピーする主ボタン
struct CopyButton: View {
    @Environment(AppModel.self) private var model
    var identifier: AdvertisingIdentifier
    var minHeight: CGFloat = 47
    var fillsWidth = true

    var body: some View {
        Button {
            model.copy(identifier)
        } label: {
            Label("Copy", systemImage: "square.on.square")
                .font(.system(size: 16, weight: .bold))
        }
        .buttonStyle(.metal(.primary, chamfer: 10, minHeight: minHeight, fillsWidth: fillsWidth))
        .accessibilityIdentifier("copy")
    }
}

/// IDFA の文字列を共有する副ボタン
struct ShareIdentifierButton: View {
    var identifier: AdvertisingIdentifier
    var minHeight: CGFloat = 47
    var fillsWidth = true

    var body: some View {
        ShareLink(item: identifier.value) {
            Label("Share", systemImage: "square.and.arrow.up")
                .font(.system(size: 16, weight: .bold))
        }
        .buttonStyle(.metal(.secondary, chamfer: 10, minHeight: minHeight, fillsWidth: fillsWidth))
    }
}

/// コピーしたときの短い表示
struct CopyToast: View {
    var body: some View {
        Label("Copied", systemImage: "checkmark")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(HeatTint.text)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background {
                MetalSurface(chamfer: 10, rimWidth: 1.5, rim: HeatTint.secondaryRim) {
                    Color(hex: 0x0B0E24, opacity: 0.96)
                }
                .shadow(color: .black.opacity(0.7), radius: 10, y: 8)
            }
    }
}

extension View {
    /// コピーしたら、触覚フィードバックと「コピーしました」を短く出す
    func copyFeedback(count: Int) -> some View {
        modifier(CopyFeedback(count: count))
    }
}

private struct CopyFeedback: ViewModifier {
    var count: Int
    @State private var isShowingToast = false
    @State private var hideTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if isShowingToast {
                    CopyToast()
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .copyHaptics(trigger: count)
            .onChange(of: count) {
                withAnimation(.snappy) { isShowingToast = true }
                AccessibilityNotification.Announcement(String(localized: "Copied")).post()
                hideTask?.cancel()
                hideTask = Task {
                    try? await Task.sleep(for: .seconds(1.6))
                    guard !Task.isCancelled else {
                        return
                    }
                    withAnimation(.easeOut) { isShowingToast = false }
                }
            }
    }
}

private extension View {
    /// コピーの触覚フィードバック。visionOS には触覚が無い（sensoryFeedback も visionOS 26 から）ので付けない
    @ViewBuilder
    func copyHaptics(trigger: Int) -> some View {
        #if os(visionOS)
        self
        #else
        sensoryFeedback(.success, trigger: trigger)
        #endif
    }
}
