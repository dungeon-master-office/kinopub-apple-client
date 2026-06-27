//
//  PaginatedItemsResponse.swift
//
//
//  Created by Kirill Kunst on 26.07.2023.
//

import Foundation

public struct PaginatedData<T: Codable>: Codable {

  public var items: [T]
  public var pagination: Pagination

  private enum CodingKeys: String, CodingKey {
    case items
    case pagination
  }

  public init(items: [T], pagination: Pagination) {
    self.items = items
    self.pagination = pagination
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    // Decode items lossily: a single undecodable element (e.g. a title with an unexpected null in a
    // non-optional field) must NOT empty the whole list — that previously broke actor/director
    // searches whenever one matched title carried bad data.
    self.items = container.decodeLossyArray(T.self, forKey: .items)
    self.pagination = try container.decode(Pagination.self, forKey: .pagination)
  }

  public static func mock(data: [T]) -> PaginatedData {
    return PaginatedData(items: data, pagination: Pagination(total: 0, current: 0, perpage: 0))
  }

}
