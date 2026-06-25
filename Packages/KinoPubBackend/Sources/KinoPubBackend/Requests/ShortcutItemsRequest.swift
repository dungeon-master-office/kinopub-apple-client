//
//  ShortcutItemsRequest.swift
//
//
//  Created by Kirill Kunst on 28.07.2023.
//

import Foundation

public struct ShortcutItemsRequest: Endpoint {

  private var shortcut: MediaShortcut
  private var contentType: MediaType
  private var page: Int?

  public init(shortcut: MediaShortcut, contentType: MediaType, page: Int? = nil) {
    self.shortcut = shortcut
    self.contentType = contentType
    self.page = page
  }

  public var path: String {
    "/v1/items/\(shortcut.rawValue)"
  }

  public var method: String {
    "GET"
  }

  public var parameters: [String: Any]? {
    var params = [
      "type": contentType.rawValue
    ]

    if let page = page {
      params["page"] = "\(page)"
    }

    return params
  }

  public var headers: [String: String]? {
    nil
  }

  public var forceSendAsGetParams: Bool { false }
}

extension ShortcutItemsRequest: CacheableRequest {
  // Cache only the first page briefly, so returning to a list is flicker-free. Pagination pages are
  // transient scroll state and aren't cached. Pull-to-refresh bypasses via `forceRefresh`.
  public var cachePolicy: CachePolicy {
    (page == nil || page == 1) ? .memory(ttl: 120) : .noCache
  }
}
