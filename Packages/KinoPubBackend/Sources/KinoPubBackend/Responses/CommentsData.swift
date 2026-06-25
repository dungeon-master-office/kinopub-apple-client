//
//  CommentsData.swift
//
//
//  Response wrapper for GET /v1/items/comments.
//

import Foundation

public struct CommentsData: Decodable {
  public let comments: [Comment]

  public init(comments: [Comment]) {
    self.comments = comments
  }

  private enum CodingKeys: String, CodingKey {
    case comments
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    // Lossy: a single malformed/deleted comment must not drop the whole thread.
    comments = container.decodeLossyArray(Comment.self, forKey: .comments)
  }

  public static func mock(_ comments: [Comment] = []) -> CommentsData {
    CommentsData(comments: comments)
  }
}
