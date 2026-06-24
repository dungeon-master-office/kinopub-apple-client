//
//  UpdateDeviceSettingsRequest.swift
//
//
//  Created by Kirill Kunst on 25.06.2026.
//

import Foundation

public struct UpdateDeviceSettingsRequest: Endpoint {

  public var id: Int
  public var settings: DeviceSettings

  public init(id: Int, settings: DeviceSettings) {
    self.id = id
    self.settings = settings
  }

  public var path: String {
    "/v1/device/\(id)/settings"
  }

  public var method: String {
    "POST"
  }

  public var parameters: [String: Any]? {
    // Bools are sent as 1/0 ints, matching the int-style params other endpoints
    // (MarkTime / ToggleWatching / ToggleBookmarkFolder) use over query params.
    [
      "useSsl": settings.useSsl ? 1 : 0,
      "supportHevc": settings.supportHevc ? 1 : 0,
      "supportHdr": settings.supportHdr ? 1 : 0,
      "support4k": settings.support4k ? 1 : 0,
      "mixedPlaylist": settings.mixedPlaylist ? 1 : 0,
      "streamingType": settings.streamingType,
      "serverLocation": settings.serverLocation
    ]
  }

  public var headers: [String: String]? {
    nil
  }

  public var forceSendAsGetParams: Bool { true }
}
