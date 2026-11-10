//
//  DeviceInfo.swift
//  IDFAVault
//
//  この端末の識別子と表示名（仕様書 2・5 章）。
//  識別子はアプリが作った UUID を Keychain に保存して使う（IDFV は Mac で使えないため使わない）。
//  表示名は、iOS はモデル名（例: iPhone 16 Pro）、Mac はコンピュータ名、visionOS は Apple Vision Pro。
//

import Foundation
import Security
#if canImport(UIKit)
import UIKit
#endif

/// この端末の情報を返すもの。テストでは偽物に差し替える
protocol DeviceInfoProviding {
    var deviceID: String { get }
    var platform: DevicePlatform { get }
    /// 表示名（Mac のコンピュータ名は読むのに時間がかかることがあるので非同期）
    func displayName() async -> String
}

struct SystemDeviceInfo: DeviceInfoProviding {
    let deviceID: String = DeviceIDStore.loadOrCreate()
    var platform: DevicePlatform { .current }

    func displayName() async -> String {
        #if os(macOS)
        let name = await Task.detached { Host.current().localizedName }.value
        return name ?? "Mac"
        #elseif os(visionOS)
        return "Apple Vision Pro"
        #else
        return DeviceModelName.name(for: DeviceModelName.currentIdentifier, fallback: UIDevice.current.model)
        #endif
    }
}

/// 端末の UUID を Keychain に保存する。同期しない（端末ごとに別の値にする）
enum DeviceIDStore {
    private static let service = "jp.shilokuma.IDFAVault.device"
    private static let account = "deviceID"
    /// Keychain を使えないとき（アドホック署名の Mac など）の置き場所
    private static let fallbackKey = "device.id"

    static func loadOrCreate() -> String {
        if let stored = load() {
            return stored
        }
        let created = UserDefaults.standard.string(forKey: fallbackKey) ?? UUID().uuidString
        if !save(created) {
            UserDefaults.standard.set(created, forKey: fallbackKey)
        }
        return created
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true
        ]
    }

    private static func load() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(bytes: data, encoding: .utf8),
              UUID(uuidString: value) != nil else {
            return nil
        }
        return value
    }

    private static func save(_ value: String) -> Bool {
        var query = baseQuery
        query[kSecValueData as String] = Data(value.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        query[kSecAttrSynchronizable as String] = false
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }
}

/// iPhone・iPad のモデルの識別子（例: iPhone17,1）から、表示名を引く
enum DeviceModelName {
    /// この端末のモデルの識別子。Simulator では、まねしている端末の識別子
    static var currentIdentifier: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }
        var systemInfo = utsname()
        uname(&systemInfo)
        let bytes = withUnsafeBytes(of: &systemInfo.machine) { buffer in
            Array(buffer.prefix { $0 != 0 })
        }
        return String(bytes: bytes, encoding: .utf8) ?? ""
    }

    /// 表示名。表に無い（新しい）モデルは、iPad なら識別子から系統（iPad Pro など）を引けないので fallback を返す
    static func name(for identifier: String, fallback: String) -> String {
        if let name = iPhones[identifier] {
            return name
        }
        if let family = iPadFamilies[identifier] {
            return family
        }
        return fallback
    }

    /// iPhone（2018 年以降）。新しいモデルは表に足す
    private static let iPhones: [String: String] = [
        "iPhone11,2": "iPhone XS", "iPhone11,4": "iPhone XS Max", "iPhone11,6": "iPhone XS Max", "iPhone11,8": "iPhone XR",
        "iPhone12,1": "iPhone 11", "iPhone12,3": "iPhone 11 Pro", "iPhone12,5": "iPhone 11 Pro Max", "iPhone12,8": "iPhone SE",
        "iPhone13,1": "iPhone 12 mini", "iPhone13,2": "iPhone 12", "iPhone13,3": "iPhone 12 Pro", "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone14,2": "iPhone 13 Pro", "iPhone14,3": "iPhone 13 Pro Max", "iPhone14,4": "iPhone 13 mini", "iPhone14,5": "iPhone 13",
        "iPhone14,6": "iPhone SE", "iPhone14,7": "iPhone 14", "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro", "iPhone15,3": "iPhone 14 Pro Max", "iPhone15,4": "iPhone 15", "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro", "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone17,1": "iPhone 16 Pro", "iPhone17,2": "iPhone 16 Pro Max", "iPhone17,3": "iPhone 16", "iPhone17,4": "iPhone 16 Plus",
        "iPhone17,5": "iPhone 16e"
    ]

    /// iPad は世代が多いので、系統（iPad Pro・iPad Air・iPad mini）までにする
    private static let iPadFamilies: [String: String] = {
        var table: [String: String] = [:]
        let pro = [
            "iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4", "iPad8,5", "iPad8,6", "iPad8,7", "iPad8,8", "iPad8,9", "iPad8,10", "iPad8,11",
            "iPad8,12", "iPad13,4", "iPad13,5", "iPad13,6", "iPad13,7", "iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11",
            "iPad14,3", "iPad14,4", "iPad14,5", "iPad14,6", "iPad16,3", "iPad16,4", "iPad16,5", "iPad16,6"
        ]
        let air = [
            "iPad11,3", "iPad11,4", "iPad13,1", "iPad13,2", "iPad13,16", "iPad13,17", "iPad14,8", "iPad14,9", "iPad14,10", "iPad14,11"
        ]
        let mini = ["iPad11,1", "iPad11,2", "iPad14,1", "iPad14,2", "iPad16,1", "iPad16,2"]
        pro.forEach { table[$0] = "iPad Pro" }
        air.forEach { table[$0] = "iPad Air" }
        mini.forEach { table[$0] = "iPad mini" }
        return table
    }()
}
