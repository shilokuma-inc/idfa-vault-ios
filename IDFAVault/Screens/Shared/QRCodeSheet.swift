//
//  QRCodeSheet.swift
//  IDFAVault
//
//  IDFA の QR コード（仕様書 3.3。iPad・Mac・visionOS）。CoreImage の qrCodeGenerator で作る。
//

import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

enum QRCode {
    /// text の QR コード。1 モジュールを scale ピクセルにする（拡大してもにじまないよう、表示は補間しない）
    static func image(for text: String, scale: CGFloat = 12) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) else {
            return nil
        }
        return CIContext().createCGImage(output, from: output.extent)
    }
}

/// 端末の IDFA の QR コードを出すシート
struct QRCodeSheet: View {
    var identifier: AdvertisingIdentifier
    var deviceName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text(verbatim: deviceName)
                .font(.system(size: 22, weight: .heavy))
                .headingMetal()
            if let image = QRCode.image(for: identifier.value) {
                Image(decorative: image, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(18)
                    .background(ChamferedRect(chamfer: 14).fill(.white))
                    .frame(width: 260, height: 260)
                    .padding(10)
                    .ingotBackground(chamfer: 24, rimWidth: 8)
                    .accessibilityLabel(Text("QR code of the IDFA"))
            }
            Text(verbatim: identifier.value)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .identifierMetal()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 16, weight: .bold))
            }
            .buttonStyle(.metal(.secondary, chamfer: 10, minHeight: 44, fillsWidth: false))
            .keyboardShortcut(.cancelAction)
        }
        .padding(32)
        .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
        .background(HeatTintBackground())
        .presentationBackground {
            HeatTintBackground()
        }
        .preferredColorScheme(.dark)
    }
}
