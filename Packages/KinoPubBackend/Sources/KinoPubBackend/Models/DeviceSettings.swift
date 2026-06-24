//
//  DeviceSettings.swift
//
//
//  Created by Kirill Kunst on 25.06.2026.
//

import Foundation

public struct DeviceSettings: Codable {

  public var useSsl: Bool
  public var supportHevc: Bool
  public var supportHdr: Bool
  public var support4k: Bool
  public var mixedPlaylist: Bool
  public var streamingType: Int
  public var serverLocation: Int

  private struct AnyKey: CodingKey {
    var stringValue: String
    init(_ value: String) { stringValue = value }
    init?(stringValue: String) { self.stringValue = stringValue }
    var intValue: Int? { nil }
    init?(intValue: Int) { nil }
  }

  public init(useSsl: Bool = false,
              supportHevc: Bool = false,
              supportHdr: Bool = false,
              support4k: Bool = false,
              mixedPlaylist: Bool = false,
              streamingType: Int = 0,
              serverLocation: Int = 0) {
    self.useSsl = useSsl
    self.supportHevc = supportHevc
    self.supportHdr = supportHdr
    self.support4k = support4k
    self.mixedPlaylist = mixedPlaylist
    self.streamingType = streamingType
    self.serverLocation = serverLocation
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: AnyKey.self)
    // The API uses camelCase keys; older payloads use snake_case. Try both per field.
    func boolFor(_ names: [String]) -> Bool {
      for name in names {
        let key = AnyKey(name)
        if let value = try? container.decode(Bool.self, forKey: key) { return value }
        if let value = try? container.decode(Int.self, forKey: key) { return value != 0 }
        if let value = try? container.decode(String.self, forKey: key) {
          return value == "1" || value.lowercased() == "true"
        }
      }
      return false
    }
    func intFor(_ names: [String]) -> Int {
      for name in names {
        let key = AnyKey(name)
        if let value = try? container.decode(Int.self, forKey: key) { return value }
        if let value = try? container.decode(String.self, forKey: key), let parsed = Int(value) { return parsed }
      }
      return 0
    }
    self.useSsl = boolFor(["useSsl", "use_ssl"])
    self.supportHevc = boolFor(["supportHevc", "support_hevc"])
    self.supportHdr = boolFor(["supportHdr", "support_hdr"])
    self.support4k = boolFor(["support4k", "support_4k"])
    self.mixedPlaylist = boolFor(["mixedPlaylist", "mixed_playlist"])
    self.streamingType = intFor(["streamingType", "streaming_type"])
    self.serverLocation = intFor(["serverLocation", "server_location"])
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: AnyKey.self)
    try container.encode(useSsl, forKey: AnyKey("useSsl"))
    try container.encode(supportHevc, forKey: AnyKey("supportHevc"))
    try container.encode(supportHdr, forKey: AnyKey("supportHdr"))
    try container.encode(support4k, forKey: AnyKey("support4k"))
    try container.encode(mixedPlaylist, forKey: AnyKey("mixedPlaylist"))
    try container.encode(streamingType, forKey: AnyKey("streamingType"))
    try container.encode(serverLocation, forKey: AnyKey("serverLocation"))
  }

  public static func mock() -> DeviceSettings {
    DeviceSettings(useSsl: true,
                   supportHevc: true,
                   supportHdr: false,
                   support4k: true,
                   mixedPlaylist: false,
                   streamingType: 0,
                   serverLocation: 0)
  }
}
