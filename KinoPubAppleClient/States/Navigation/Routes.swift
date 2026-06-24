//
//  Routes.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 31.07.2023.
//

import Foundation
import KinoPubBackend

enum SearchRoutes: Hashable {
  case details(MediaItem)
  case seasons([Season])
  case season(Season)
  case player(any PlayableItem)
  case trailerPlayer(any PlayableItem)
  case genre(Int, String)

  func hash(into hasher: inout Hasher) {
    switch self {
    case .details(let item):
      hasher.combine(item)
    case .season(let season):
      hasher.combine(season)
    case .seasons(let seasons):
      hasher.combine(seasons)
    case .player(let item):
      hasher.combine(item.id)
    case .trailerPlayer(let item):
      hasher.combine(item.id)
    case .genre(let id, let title):
      hasher.combine(id)
      hasher.combine(title)
    }
  }

  static func == (lhs: SearchRoutes, rhs: SearchRoutes) -> Bool {
    rhs.hashValue == lhs.hashValue
  }
}

enum MainRoutes: Hashable {
  case details(MediaItem)
  case seasons([Season])
  case season(Season)
  case player(any PlayableItem)
  case trailerPlayer(any PlayableItem)
  
  func hash(into hasher: inout Hasher) {
    switch self {
    case .details(let item):
      hasher.combine(item)
    case .season(let season):
      hasher.combine(season)
    case .seasons(let seasons):
      hasher.combine(seasons)
    case .player(let item):
      hasher.combine(item.id)
    case .trailerPlayer(let item):
      hasher.combine(item.id)
    }
  }
  
  static func == (lhs: MainRoutes, rhs: MainRoutes) -> Bool {
    rhs.hashValue == lhs.hashValue
  }
}

enum BookmarksRoutes: Hashable {
  case bookmark(Bookmark)
  case details(MediaItem)
  case seasons([Season])
  case season(Season)
  case player(any PlayableItem)
  case trailerPlayer(any PlayableItem)
  
  func hash(into hasher: inout Hasher) {
    switch self {
    case .bookmark(let bookmark):
      hasher.combine(bookmark)
    case .details(let item):
      hasher.combine(item)
    case .season(let season):
      hasher.combine(season)
    case .seasons(let seasons):
      hasher.combine(seasons)
    case .player(let item):
      hasher.combine(item.id)
    case .trailerPlayer(let item):
      hasher.combine(item.id)
    }
  }
  
  static func == (lhs: BookmarksRoutes, rhs: BookmarksRoutes) -> Bool {
    rhs.hashValue == lhs.hashValue
  }
}

enum HistoryRoutes: Hashable {
  case details(MediaItem)
  case seasons([Season])
  case season(Season)
  case player(any PlayableItem)
  case trailerPlayer(any PlayableItem)

  func hash(into hasher: inout Hasher) {
    switch self {
    case .details(let item):
      hasher.combine(item)
    case .season(let season):
      hasher.combine(season)
    case .seasons(let seasons):
      hasher.combine(seasons)
    case .player(let item):
      hasher.combine(item.id)
    case .trailerPlayer(let item):
      hasher.combine(item.id)
    }
  }

  static func == (lhs: HistoryRoutes, rhs: HistoryRoutes) -> Bool {
    rhs.hashValue == lhs.hashValue
  }
}

enum WatchingRoutes: Hashable {
  case details(Int)
  case seasons([Season])
  case season(Season)
  case player(any PlayableItem)
  case trailerPlayer(any PlayableItem)

  func hash(into hasher: inout Hasher) {
    switch self {
    case .details(let id):
      hasher.combine(id)
    case .season(let season):
      hasher.combine(season)
    case .seasons(let seasons):
      hasher.combine(seasons)
    case .player(let item):
      hasher.combine(item.id)
    case .trailerPlayer(let item):
      hasher.combine(item.id)
    }
  }

  static func == (lhs: WatchingRoutes, rhs: WatchingRoutes) -> Bool {
    rhs.hashValue == lhs.hashValue
  }
}

enum DownloadsRoutes: Hashable {
  case player(any PlayableItem)
  case trailerPlayer(any PlayableItem)
  
  func hash(into hasher: inout Hasher) {
    switch self {
    case .player(let item):
      hasher.combine(item.id)
    case .trailerPlayer(let item):
      hasher.combine(item.id)
    }
  }
  
  static func == (lhs: DownloadsRoutes, rhs: DownloadsRoutes) -> Bool {
    rhs.hashValue == lhs.hashValue
  }
}
