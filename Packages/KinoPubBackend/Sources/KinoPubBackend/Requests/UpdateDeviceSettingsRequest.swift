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
    // Send both camelCase (documented) and snake_case key namings so the update applies
    // regardless of which the backend expects; unknown keys are ignored.
    let useSsl = settings.useSsl ? 1 : 0
    let hevc = settings.supportHevc ? 1 : 0
    let hdr = settings.supportHdr ? 1 : 0
    let k4 = settings.support4k ? 1 : 0
    let mixed = settings.mixedPlaylist ? 1 : 0
    return [
      "useSsl": useSsl, "use_ssl": useSsl,
      "supportHevc": hevc, "support_hevc": hevc,
      "supportHdr": hdr, "support_hdr": hdr,
      "support4k": k4, "support_4k": k4,
      "mixedPlaylist": mixed, "mixed_playlist": mixed,
      "streamingType": settings.streamingType, "streaming_type": settings.streamingType,
      "serverLocation": settings.serverLocation, "server_location": settings.serverLocation
    ]
  }

  public var headers: [String: String]? {
    nil
  }

  public var forceSendAsGetParams: Bool { true }
}
