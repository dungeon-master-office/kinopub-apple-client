//
//  WatchingSerialsRequest.swift
//
//
//  Created by Kirill Kunst on 24.06.2026.
//

import Foundation

public struct WatchingSerialsRequest: Endpoint {

  // 0 — all unwatched serials with new episodes, 1 — only serials in the watchlist
  private var subscribed: Int?
  // Content-type sub-filter for the new-episodes tab (serial / docuserial / tvshow),
  // mirroring the web /media/new-serial-episodes?type=… . Best-effort: when nil the
  // existing subscribed-only behaviour is unchanged.
  private var type: String?

  public init(subscribed: Int? = nil, type: String? = nil) {
    self.subscribed = subscribed
    self.type = type
  }

  public var path: String {
    "/v1/watching/serials"
  }

  public var method: String {
    "GET"
  }

  public var parameters: [String: Any]? {
    var params: [String: Any] = [:]
    if let subscribed = subscribed {
      params["subscribed"] = subscribed
    }
    if let type = type {
      params["type"] = type
    }
    return params.isEmpty ? nil : params
  }

  public var headers: [String: String]? {
    nil
  }

  public var forceSendAsGetParams: Bool { false }
}
