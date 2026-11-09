//
//  AdvertisingIdentifierTests.swift
//  IDFAVaultTests
//

import Foundation
@testable import IDFAVault
import Testing

struct AdvertisingIdentifierTests {
    private let identifier = AdvertisingIdentifier("6d92078a-8246-4ba4-ae5b-76104861e7dc")

    @Test
    func valueIsUppercasedWithHyphens() throws {
        let identifier = try #require(identifier)
        #expect(identifier.value == "6D92078A-8246-4BA4-AE5B-76104861E7DC")
    }

    @Test
    func rejectsStringsThatAreNotUUIDs() {
        #expect(AdvertisingIdentifier("not-an-idfa") == nil)
        #expect(AdvertisingIdentifier("") == nil)
    }

    @Test
    func zeroIsDetected() throws {
        #expect(AdvertisingIdentifier.zero.value == "00000000-0000-0000-0000-000000000000")
        #expect(AdvertisingIdentifier.zero.isZero)
        #expect(try #require(AdvertisingIdentifier("00000000-0000-0000-0000-000000000000")).isZero)
        #expect(try !#require(identifier).isZero)
    }

    /// iPhone では 3 つ目のハイフンのあとで 2 行に分ける（仕様書 6.5）
    @Test
    func splitsIntoTwoLinesAfterTheThirdGroup() throws {
        let lines = try #require(identifier).twoLines
        #expect(lines.first == "6D92078A-8246-4BA4-")
        #expect(lines.second == "AE5B-76104861E7DC")
    }

    /// 他の端末の伏せ字は先頭 4 桁と末尾 4 桁だけを見せる（仕様書 3.4）
    @Test
    func masksAllButTheFirstAndLastFourCharacters() throws {
        let identifier = try #require(AdvertisingIdentifier("A1C4B83E-5D20-4F7A-8C61-0E9B2D4C9F21"))
        #expect(identifier.masked == "A1C4••••-••••-9F21")
        #expect(identifier.shortMasked == "A1C4••••-9F21")
    }
}
