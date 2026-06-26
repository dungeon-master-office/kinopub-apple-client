//
//  CollectionsData.swift
//
//
//  Created by Kirill Kunst on 24.06.2026.
//

import Foundation

public struct CollectionsData: Decodable {

  public let collections: [Collection]
  public let pagination: Pagination?

  private enum CodingKeys: String, CodingKey {
    case collections
    case items
    case pagination
  }

  public init(collections: [Collection], pagination: Pagination? = nil) {
    self.collections = collections
    self.pagination = pagination
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    // Decode defensively: API may use either "collections" or "items".
    if let collections = try container.decodeIfPresent([Collection].self, forKey: .collections) {
      self.collections = collections
    } else {
      self.collections = try container.decodeIfPresent([Collection].self, forKey: .items) ?? []
    }
    self.pagination = try container.decodeIfPresent(Pagination.self, forKey: .pagination)
  }

  public static func mock(data: [Collection] = []) -> CollectionsData {
    CollectionsData(collections: data, pagination: Pagination(total: 0, current: 0, perpage: 0))
  }
}
