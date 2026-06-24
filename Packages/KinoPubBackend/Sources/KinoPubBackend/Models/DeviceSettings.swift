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

  private enum CodingKeys: String, CodingKey {
    case useSsl = "use_ssl"
    case supportHevc = "support_hevc"
    case supportHdr = "support_hdr"
    case support4k = "support_4k"
    case mixedPlaylist = "mixed_playlist"
    case streamingType = "streaming_type"
    case serverLocation = "server_location"
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
    let container = try decoder.container(keyedBy: CodingKeys.self)
    // Decode defensively: missing flags default to false, missing ints to 0.
    self.useSsl = DeviceSettings.decodeBool(container, .useSsl)
    self.supportHevc = DeviceSettings.decodeBool(container, .supportHevc)
    self.supportHdr = DeviceSettings.decodeBool(container, .supportHdr)
    self.support4k = DeviceSettings.decodeBool(container, .support4k)
    self.mixedPlaylist = DeviceSettings.decodeBool(container, .mixedPlaylist)
    self.streamingType = DeviceSettings.decodeInt(container, .streamingType)
    self.serverLocation = DeviceSettings.decodeInt(container, .serverLocation)
  }

  /// Accepts a flag as Bool, Int (1/0) or numeric String.
  private static func decodeBool(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Bool {
    if let value = try? container.decode(Bool.self, forKey: key) {
      return value
    }
    if let value = try? container.decode(Int.self, forKey: key) {
      return value != 0
    }
    if let value = try? container.decode(String.self, forKey: key) {
      return value == "1" || value.lowercased() == "true"
    }
    return false
  }

  /// Accepts an int as Int or numeric String.
  private static func decodeInt(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int {
    if let value = try? container.decode(Int.self, forKey: key) {
      return value
    }
    if let value = try? container.decode(String.self, forKey: key), let parsed = Int(value) {
      return parsed
    }
    return 0
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
