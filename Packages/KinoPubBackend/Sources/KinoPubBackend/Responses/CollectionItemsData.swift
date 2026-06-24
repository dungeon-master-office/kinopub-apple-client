//
//  CollectionItemsData.swift
//
//
//  Created by Kirill Kunst on 24.06.2026.
//

import Foundation

public struct CollectionItemsData: Decodable {

  public let collection: Collection?
  public let items: [MediaItem]

  private enum CodingKeys: String, CodingKey {
    case collection
    case items
  }

  public init(collection: Collection?, items: [MediaItem]) {
    self.collection = collection
    self.items = items
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.collection = try container.decodeIfPresent(Collection.self, forKey: .collection)
    // Decode defensively & lossily: if a single MediaItem fails to decode we must
    // NOT lose the whole collection. Decode element by element, skipping failures.
    self.items = container.decodeLossyArray(MediaItem.self, forKey: .items)
  }

  public static func mock(collection: Collection? = nil, items: [MediaItem] = []) -> CollectionItemsData {
    CollectionItemsData(collection: collection, items: items)
  }
}

extension KeyedDecodingContainer {
  /// Decodes an array of `T` lossily: each element is decoded independently and
  /// any element that fails to decode is skipped instead of throwing and dropping
  /// the entire array. Returns an empty array when the key is absent.
  func decodeLossyArray<T: Decodable>(_ type: T.Type, forKey key: Key) -> [T] {
    // A throwaway wrapper that decodes a single element via an unkeyed container,
    // tolerating individual element failures.
    struct AnyDecodable: Decodable {}

    guard contains(key) else { return [] }
    guard var unkeyed = try? nestedUnkeyedContainer(forKey: key) else { return [] }

    var result: [T] = []
    if let count = unkeyed.count {
      result.reserveCapacity(count)
    }
    while !unkeyed.isAtEnd {
      if let value = try? unkeyed.decode(T.self) {
        result.append(value)
      } else {
        // Element failed to decode: consume it so the loop advances.
        _ = try? unkeyed.decode(AnyDecodable.self)
      }
    }
    return result
  }
}
