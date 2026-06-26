//
//  DeviceSettings.swift
//
//
//  Created by Kirill Kunst on 25.06.2026.
//

import Foundation

/// One option of a "list"-type device setting (e.g. a stream type or a server location).
public struct DeviceSettingOption: Codable, Identifiable, Hashable {
  public let id: Int
  public let label: String
  public init(id: Int, label: String) {
    self.id = id
    self.label = label
  }
}

public struct DeviceSettings: Codable {

  public var supportSsl: Bool
  public var supportHevc: Bool
  public var supportHdr: Bool
  public var support4k: Bool
  public var mixedPlaylist: Bool
  /// Selected stream-type id (e.g. 4 = HLS4). The available options come from the server.
  public var streamingType: Int
  /// Selected server id (e.g. 1 = Netherlands). The available options come from the server.
  public var serverLocation: Int

  public var streamingTypeOptions: [DeviceSettingOption]
  public var serverLocationOptions: [DeviceSettingOption]

  private struct AnyKey: CodingKey {
    var stringValue: String
    init(_ value: String) { stringValue = value }
    init?(stringValue: String) { self.stringValue = stringValue }
    var intValue: Int? { nil }
    init?(intValue: Int) { nil }
  }

  public init(supportSsl: Bool = false,
              supportHevc: Bool = false,
              supportHdr: Bool = false,
              support4k: Bool = false,
              mixedPlaylist: Bool = false,
              streamingType: Int = 0,
              serverLocation: Int = 0,
              streamingTypeOptions: [DeviceSettingOption] = [],
              serverLocationOptions: [DeviceSettingOption] = []) {
    self.supportSsl = supportSsl
    self.supportHevc = supportHevc
    self.supportHdr = supportHdr
    self.support4k = support4k
    self.mixedPlaylist = mixedPlaylist
    self.streamingType = streamingType
    self.serverLocation = serverLocation
    self.streamingTypeOptions = streamingTypeOptions
    self.serverLocationOptions = serverLocationOptions
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: AnyKey.self)

    // Scalar settings arrive as a nested object `{ "value": 1, "label": "…" }`. Fall back to a flat
    // scalar (the update echo / mocks) so both shapes decode.
    func scalarBool(_ name: String) -> Bool {
      if let nested = try? container.nestedContainer(keyedBy: AnyKey.self, forKey: AnyKey(name)) {
        if let value = try? nested.decode(Int.self, forKey: AnyKey("value")) { return value != 0 }
        if let value = try? nested.decode(Bool.self, forKey: AnyKey("value")) { return value }
      }
      if let value = try? container.decode(Int.self, forKey: AnyKey(name)) { return value != 0 }
      if let value = try? container.decode(Bool.self, forKey: AnyKey(name)) { return value }
      return false
    }

    struct ListItem: Decodable {
      let id: Int
      let label: String
      let selected: Int?
    }

    // List settings arrive as `{ "type": "list", "value": [ { id, label, selected } ] }`.
    func listSetting(_ name: String) -> (selected: Int, options: [DeviceSettingOption]) {
      if let nested = try? container.nestedContainer(keyedBy: AnyKey.self, forKey: AnyKey(name)),
         let items = try? nested.decode([ListItem].self, forKey: AnyKey("value")) {
        let options = items.map { DeviceSettingOption(id: $0.id, label: $0.label) }
        let selected = items.first(where: { ($0.selected ?? 0) == 1 })?.id ?? items.first?.id ?? 0
        return (selected, options)
      }
      if let value = try? container.decode(Int.self, forKey: AnyKey(name)) { return (value, []) }
      return (0, [])
    }

    supportSsl = scalarBool("supportSsl")
    supportHevc = scalarBool("supportHevc")
    supportHdr = scalarBool("supportHdr")
    support4k = scalarBool("support4k")
    mixedPlaylist = scalarBool("mixedPlaylist")
    let stream = listSetting("streamingType")
    streamingType = stream.selected
    streamingTypeOptions = stream.options
    let server = listSetting("serverLocation")
    serverLocation = server.selected
    serverLocationOptions = server.options
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: AnyKey.self)
    try container.encode(supportSsl ? 1 : 0, forKey: AnyKey("supportSsl"))
    try container.encode(supportHevc ? 1 : 0, forKey: AnyKey("supportHevc"))
    try container.encode(supportHdr ? 1 : 0, forKey: AnyKey("supportHdr"))
    try container.encode(support4k ? 1 : 0, forKey: AnyKey("support4k"))
    try container.encode(mixedPlaylist ? 1 : 0, forKey: AnyKey("mixedPlaylist"))
    try container.encode(streamingType, forKey: AnyKey("streamingType"))
    try container.encode(serverLocation, forKey: AnyKey("serverLocation"))
  }

  public static func mock() -> DeviceSettings {
    DeviceSettings(supportSsl: true,
                   supportHevc: true,
                   supportHdr: false,
                   support4k: true,
                   mixedPlaylist: false,
                   streamingType: 4,
                   serverLocation: 1,
                   streamingTypeOptions: [DeviceSettingOption(id: 2, label: "HLS"),
                                          DeviceSettingOption(id: 3, label: "HLS2"),
                                          DeviceSettingOption(id: 4, label: "HLS4")],
                   serverLocationOptions: [DeviceSettingOption(id: 1, label: "Нидерланды"),
                                           DeviceSettingOption(id: 3, label: "Россия")])
  }
}
