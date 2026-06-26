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
    // Exactly the fields the kino.pub web modal posts (verified from the live form):
    //   streamingType=4&serverLocation=1&support4k=0&supportHevc=0
    // camelCase keys, booleans as 1/0, in the form body. SSL/HDR/mixedPlaylist aren't editable
    // through this endpoint, so we don't send them.
    return [
      "streamingType": settings.streamingType,
      "serverLocation": settings.serverLocation,
      "support4k": settings.support4k ? 1 : 0,
      "supportHevc": settings.supportHevc ? 1 : 0
    ]
  }

  public var headers: [String: String]? {
    nil
  }

  // Send the settings in the form-urlencoded body (not the query string) — like /v1/device/notify,
  // kino.pub only applies these when they arrive in the POST body, so query params silently no-op
  // and the settings appear to "reset" after saving.
  public var forceSendAsGetParams: Bool { false }
}
