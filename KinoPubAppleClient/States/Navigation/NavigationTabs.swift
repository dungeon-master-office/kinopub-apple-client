//
//  NavigationTabs.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 31.07.2023.
//

import Foundation
import KinoPubBackend

enum NavigationTabs: Hashable {
  case search
  case main
  case sport
  case collections
  case bookmarks
  case newEpisodes
  case watching
  case history
  case downloads
  case profile
  /// The custom iPhone "Ещё" tab (hosts everything the iPad sidebar has).
  case more
  /// A library category (Movies, Serials, …).
  case category(MediaType)
}

/// Sidebar destinations for the iPad / macOS two-column layout.
/// The `library` group mirrors the kino.pub website categories, the rest live in the "Other" group.
/// Catalog "preset" sections the website exposes that aren't plain content types — they're a
/// `type` + `genre` filter combo (verified live from the web app's `/v1/items` calls):
///   Мультфильмы = movie+genre23, Мультсериалы = serial+genre23, Аниме = movie,serial+genre25,
///   Стендапы = movie+genre101, 3D = type=3d.
enum CatalogPreset: String, CaseIterable, Identifiable, Hashable {
  case cartoons, cartoonSeries, anime, standup, threeD

  var id: String { rawValue }

  var title: String {
    switch self {
    case .cartoons: return "Cartoons"
    case .cartoonSeries: return "Cartoon Series"
    case .anime: return "Anime"
    case .standup: return "Stand-up"
    case .threeD: return "3D"
    }
  }

  var systemImage: String {
    switch self {
    case .cartoons: return "teddybear"
    case .cartoonSeries: return "teddybear.fill"
    case .anime: return "sparkles"
    case .standup: return "mic"
    case .threeD: return "cube"
    }
  }

  var filter: MediaItemsFilter {
    switch self {
    case .cartoons: return MediaItemsFilter(contentType: .movie, genres: [23], countries: [])
    case .cartoonSeries: return MediaItemsFilter(contentType: .serial, genres: [23], countries: [])
    case .anime: return MediaItemsFilter(contentType: .movie, rawType: "movie,serial", genres: [25], countries: [])
    case .standup: return MediaItemsFilter(contentType: .movie, genres: [101], countries: [])
    case .threeD: return MediaItemsFilter(contentType: .movie, rawType: "3d", genres: [], countries: [])
    }
  }

  /// Presets shown in the UI (incl. 3D). Each can be hidden in Profile → Sections like any other.
  static var visible: [CatalogPreset] { allCases }
}

enum SidebarItem: Hashable, Identifiable {
  case search
  case new
  case category(MediaType)
  case preset(CatalogPreset)
  case sport
  case collections
  case newEpisodes
  case watching
  case bookmarks
  case history
  case downloads
  case profile

  var id: String {
    switch self {
    case .search: return "search"
    case .new: return "new"
    case .category(let type): return "category-\(type.rawValue)"
    case .preset(let p): return "preset-\(p.rawValue)"
    case .sport: return "sport"
    case .collections: return "collections"
    case .newEpisodes: return "new-episodes"
    case .watching: return "watching"
    case .bookmarks: return "bookmarks"
    case .history: return "history"
    case .downloads: return "downloads"
    case .profile: return "profile"
    }
  }

  // Library categories shown in the sidebar, ordered like the website.
  static let libraryCategories: [MediaType] = [
    .movie, .serial, .concert, .documovie, .docuserial, .tvshow
  ]

  /// Sections usable without a network connection (everything else is locked offline).
  var isAvailableOffline: Bool {
    switch self {
    case .downloads, .profile: return true
    default: return false
    }
  }

  var title: String {
    switch self {
    case .search: return "Search"
    case .new: return "Home"
    case .category(let type): return type.title
    case .preset(let p): return p.title
    case .sport: return "Sport"
    case .collections: return "Collections"
    case .newEpisodes: return "New episodes"
    case .watching: return "Watching"
    case .bookmarks: return "Bookmarks"
    case .history: return "History"
    case .downloads: return "Downloads"
    case .profile: return "Profile"
    }
  }

  var systemImage: String {
    switch self {
    case .search: return "magnifyingglass"
    case .new: return "house"
    case .category(let type): return type.systemImage
    case .preset(let p): return p.systemImage
    case .sport: return "sportscourt"
    case .collections: return "rectangle.stack"
    case .newEpisodes: return "sparkles.tv"
    case .watching: return "play.tv"
    case .bookmarks: return "bookmark"
    case .history: return "clock.arrow.circlepath"
    case .downloads: return "arrow.down.circle"
    case .profile: return "person.crop.circle"
    }
  }
}
