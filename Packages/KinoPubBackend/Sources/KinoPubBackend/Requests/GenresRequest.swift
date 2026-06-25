//
//  File.swift
//  
//
//  Created by Kirill Kunst on 14.08.2023.
//

import Foundation

public struct GenresRequest: Endpoint, CacheableRequest {

  // Genres almost never change — persist for a day so filter/search screens open instantly.
  public var cachePolicy: CachePolicy { .disk(ttl: 86_400) }

  private var type: MediaType?

  public init(type: MediaType? = nil) {
    self.type = type
  }

  public var path: String {
    "/v1/genres"
  }

  public var method: String {
    "GET"
  }

  public var parameters: [String: Any]? {
    guard let type = type else { return nil }
    // Web shows different genres per section; if the API ignores `type` it
    // harmlessly returns all genres.
    return ["type": type.rawValue]
  }

  public var headers: [String: String]? {
    nil
  }

  public var forceSendAsGetParams: Bool { false }
}
