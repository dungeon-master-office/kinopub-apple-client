//
//  DeviceInfo.swift
//
//
//  Created by Kirill Kunst on 25.06.2026.
//

import Foundation

public struct DeviceInfo: Decodable, Identifiable {

  public let id: Int
  public let title: String?

  private enum CodingKeys: String, CodingKey {
    case id
    case title
    case name
  }

  public init(id: Int, title: String? = nil) {
    self.id = id
    self.title = title
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    // Decode defensively: id may arrive as Int or String; title may be under "title" or "name".
    if let intId = try? container.decode(Int.self, forKey: .id) {
      self.id = intId
    } else if let stringId = try? container.decode(String.self, forKey: .id),
              let parsed = Int(stringId) {
      self.id = parsed
    } else {
      self.id = 0
    }

    if let title = try container.decodeIfPresent(String.self, forKey: .title) {
      self.title = title
    } else {
      self.title = try container.decodeIfPresent(String.self, forKey: .name)
    }
  }

  public static func mock(id: Int = 1, title: String? = "This device") -> DeviceInfo {
    DeviceInfo(id: id, title: title)
  }
}
