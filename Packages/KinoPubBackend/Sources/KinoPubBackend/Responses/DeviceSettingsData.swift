//
//  DeviceSettingsData.swift
//
//
//  Created by Kirill Kunst on 25.06.2026.
//

import Foundation

public struct DeviceSettingsData: Decodable {

  public let settings: DeviceSettings

  private enum CodingKeys: String, CodingKey {
    case settings
  }

  public init(settings: DeviceSettings) {
    self.settings = settings
  }

  public init(from decoder: Decoder) throws {
    // Decode defensively: the settings may be nested under "settings" or live at the top level.
    if let container = try? decoder.container(keyedBy: CodingKeys.self),
       let settings = try? container.decode(DeviceSettings.self, forKey: .settings) {
      self.settings = settings
    } else {
      self.settings = try DeviceSettings(from: decoder)
    }
  }

  public static func mock(settings: DeviceSettings = .mock()) -> DeviceSettingsData {
    DeviceSettingsData(settings: settings)
  }
}
