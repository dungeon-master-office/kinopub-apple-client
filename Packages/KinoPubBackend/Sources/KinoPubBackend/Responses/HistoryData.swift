//
//  HistoryData.swift
//
//
//  Created by Kirill Kunst on 24.06.2026.
//

import Foundation

public struct HistoryItem: Codable, Hashable, Identifiable {

  public let time: TimeInterval?
  public let counter: Int?
  public let firstSeen: TimeInterval?
  public let lastSeen: TimeInterval?
  public let item: MediaItem

  public var id: Int { item.id }

  private enum CodingKeys: String, CodingKey {
    case time = "time"
    case counter = "counter"
    case firstSeen = "first_seen"
    case lastSeen = "last_seen"
    case item = "item"
  }

  public init(time: TimeInterval?,
              counter: Int?,
              firstSeen: TimeInterval?,
              lastSeen: TimeInterval?,
              item: MediaItem) {
    self.time = time
    self.counter = counter
    self.firstSeen = firstSeen
    self.lastSeen = lastSeen
    self.item = item
  }
}

public struct HistoryData: Codable {

  public let history: [HistoryItem]
  public let pagination: Pagination

  public init(history: [HistoryItem], pagination: Pagination) {
    self.history = history
    self.pagination = pagination
  }

  public static func mock(data: [HistoryItem] = []) -> HistoryData {
    return HistoryData(history: data, pagination: Pagination(total: 0, current: 0, perpage: 0))
  }

}
