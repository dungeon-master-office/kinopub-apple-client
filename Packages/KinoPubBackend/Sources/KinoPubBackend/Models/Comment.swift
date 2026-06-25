//
//  Comment.swift
//
//
//  Comment on a film/episode. Matches GET /v1/items/comments (kinoapi.com → video-comments).
//

import Foundation

public struct Comment: Codable, Identifiable {
  public let id: Int
  public let message: String
  public let created: Int
  public let rating: String?
  public let depth: Int?
  public let unread: Bool?
  public let deleted: Bool?
  public let user: CommentUser

  public init(id: Int,
              message: String,
              created: Int,
              rating: String? = nil,
              depth: Int? = nil,
              unread: Bool? = nil,
              deleted: Bool? = nil,
              user: CommentUser) {
    self.id = id
    self.message = message
    self.created = created
    self.rating = rating
    self.depth = depth
    self.unread = unread
    self.deleted = deleted
    self.user = user
  }
}

public struct CommentUser: Codable {
  public let id: Int
  public let name: String
  public let avatar: String?

  public init(id: Int, name: String, avatar: String? = nil) {
    self.id = id
    self.name = name
    self.avatar = avatar
  }
}
