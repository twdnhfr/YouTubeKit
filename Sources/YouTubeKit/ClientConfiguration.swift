//
//  ClientConfiguration.swift
//  YouTubeKit
//
//  Makes the InnerTube client list configurable at runtime, so a broken client can be
//  swapped (e.g. via a remotely loaded config) without rebuilding the app.
//

import Foundation

/// Definition of an InnerTube client, mirroring the fields yt-dlp uses in `INNERTUBE_CLIENTS`.
public struct InnerTubeClientDefinition: Codable, Sendable, Equatable {
    public var name: String
    public var version: String
    public var screen: String?
    public var apiKey: String?
    public var internalID: Int
    public var userAgent: String?
    public var playerParams: String?
    public var androidSdkVersion: Int?
    public var deviceMake: String?
    public var deviceModel: String?
    public var osName: String?
    public var osVersion: String?

    public init(name: String, version: String, screen: String? = nil, apiKey: String? = nil, internalID: Int, userAgent: String? = nil, playerParams: String? = nil, androidSdkVersion: Int? = nil, deviceMake: String? = nil, deviceModel: String? = nil, osName: String? = nil, osVersion: String? = nil) {
        self.name = name
        self.version = version
        self.screen = screen
        self.apiKey = apiKey
        self.internalID = internalID
        self.userAgent = userAgent
        self.playerParams = playerParams
        self.androidSdkVersion = androidSdkVersion
        self.deviceMake = deviceMake
        self.deviceModel = deviceModel
        self.osName = osName
        self.osVersion = osVersion
    }
}

/// Global, thread-safe runtime configuration for stream extraction.
public enum YouTubeKitConfiguration {

    /// Built-in client order used when nothing is configured.
    public static let defaultClientOrder = ["visionOS", "web"]

    private static let lock = NSLock()
    nonisolated(unsafe) private static var _clientOrder: [String] = defaultClientOrder
    nonisolated(unsafe) private static var _clientOverrides: [String: InnerTubeClientDefinition] = [:]

    /// Clients queried for streams, ordered by priority. Keys are either built-in client names
    /// (`visionOS`, `web`, `tv`, `ios`, …) or keys of `clientOverrides`.
    public static var clientOrder: [String] {
        get { lock.withLock { _clientOrder } }
        set { lock.withLock { _clientOrder = newValue.isEmpty ? defaultClientOrder : newValue } }
    }

    /// Client definitions that replace a built-in client of the same key or add a new one.
    public static var clientOverrides: [String: InnerTubeClientDefinition] {
        get { lock.withLock { _clientOverrides } }
        set { lock.withLock { _clientOverrides = newValue } }
    }

    /// Names of the built-in clients (valid keys for `clientOrder`).
    public static var builtInClientNames: [String] {
        InnerTube.ClientType.allCases.map(\.rawValue)
    }
}

#if canImport(CryptoKit)
import CryptoKit
#endif

@available(iOS 13.0, watchOS 6.0, tvOS 13.0, macOS 10.15, *)
extension InnerTube {
    /// `SAPISIDHASH <ts>_<sha1(ts SAPISID origin)>` – needed for authenticated InnerTube calls with browser cookies.
    static func sapisidHashAuthorization(cookieHeader: String, origin: String = "https://www.youtube.com") -> String? {
#if canImport(CryptoKit)
        let cookies = cookieHeader.split(separator: ";").reduce(into: [String: String]()) { result, pair in
            let parts = pair.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 { result[parts[0]] = parts[1] }
        }
        guard let sapisid = cookies["SAPISID"] ?? cookies["__Secure-3PAPISID"] else { return nil }
        let timestamp = Int(Date().timeIntervalSince1970)
        let digest = Insecure.SHA1.hash(data: Data("\(timestamp) \(sapisid) \(origin)".utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "SAPISIDHASH \(timestamp)_\(hex)"
#else
        return nil
#endif
    }
}
