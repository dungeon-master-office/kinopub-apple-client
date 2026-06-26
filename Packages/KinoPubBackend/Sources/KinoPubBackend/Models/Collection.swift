//
//  Collection.swift
//
//
//  Created by Kirill Kunst on 24.06.2026.
//

import Foundation

public struct Collection: Decodable, Identifiable, Hashable {

  public struct Posters: Decodable, Hashable {
    public let small: String?
    public let medium: String?
    public let big: String?

    public init(small: String?, medium: String?, big: String?) {
      self.small = small
      self.medium = medium
      self.big = big
    }
  }

  public let id: Int
  public let title: String
  public let watchers: Int?
  public let views: Int?
  public let created: Int?
  public let updated: Int?
  public let posters: Posters?

  private enum CodingKeys: String, CodingKey {
    case id
    case title
    case watchers
    case views
    case created
    case updated
    case posters
  }

  public init(id: Int,
              title: String,
              watchers: Int? = nil,
              views: Int? = nil,
              created: Int? = nil,
              updated: Int? = nil,
              posters: Posters? = nil) {
    self.id = id
    self.title = title
    self.watchers = watchers
    self.views = views
    self.created = created
    self.updated = updated
    self.posters = posters
  }

  public static func mock(id: Int = 0,
                          title: String = "Collection",
                          posters: Posters? = nil) -> Collection {
    Collection(id: id, title: title, posters: posters)
  }
}
