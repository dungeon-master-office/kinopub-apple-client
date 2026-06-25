//
//  CommentsRequest.swift
//
//
//  GET /v1/items/comments?id=<itemId> — comments for a film/episode.
//

import Foundation

public struct CommentsRequest: Endpoint {

  private var id: Int

  public init(id: Int) {
    self.id = id
  }

  public var path: String {
    "/v1/items/comments"
  }

  public var method: String {
    "GET"
  }

  public var parameters: [String: Any]? {
    ["id": "\(id)"]
  }

  public var headers: [String: String]? {
    nil
  }

  public var forceSendAsGetParams: Bool { false }
}
