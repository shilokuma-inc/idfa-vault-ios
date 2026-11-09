//
//  QRCodeTests.swift
//  IDFAVaultTests
//

import CoreImage
import Foundation
@testable import IDFAVault
import Testing

struct QRCodeTests {
    /// IDFA の QR コードを作れて、読み取ると同じ値に戻る（仕様書 3.3）
    @Test
    func encodesTheIdentifier() throws {
        let value = UITesting.sampleIdentifier.value

        let image = try #require(QRCode.image(for: value))

        #expect(image.width == image.height)
        let detector = try #require(CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: nil))
        let features = detector.features(in: CIImage(cgImage: image)).compactMap { $0 as? CIQRCodeFeature }
        #expect(features.first?.messageString == value)
    }
}
