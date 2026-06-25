//
//  PlayableItem.swift
//
//
//  Created by Kirill Kunst on 9.11.2023.
//

import Foundation

public protocol PlayableItem: Identifiable, Hashable, Equatable {
  var id: Int { get }
  var files: [FileInfo] { get }
  var trailer: Trailer? { get }
  var metadata: WatchingMetadata { get }
  /// Title shown in the native player (movie name or series name).
  var playerTitle: String { get }
  /// Secondary line in the native player (e.g. "S1 · E2 · Episode name").
  var playerSubtitle: String? { get }
}

public extension PlayableItem {
  var playerTitle: String { "" }
  var playerSubtitle: String? { nil }
}
