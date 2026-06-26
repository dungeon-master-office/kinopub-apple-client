//
//  NavigationTabs.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 31.07.2023.
//

import Foundation
import KinoPubBackend

enum NavigationTabs {
  case search
  case main
  case sport
  case collections
  case bookmarks
  case watching
  case history
  case downloads
  case profile
}

/// Sidebar destinations for the iPad / macOS two-column layout.
/// The `library` group mirrors the kino.pub website categories, the rest live in the "Other" group.
enum SidebarItem: Hashable, Identifiable {
  case search
  case new
  case category(MediaType)
  case sport
  case collections
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
    case .sport: return "sport"
    case .collections: return "collections"
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

  var title: String {
    switch self {
    case .search: return "Search"
    case .new: return "Home"
    case .category(let type): return type.title
    case .sport: return "Sport"
    case .collections: return "Collections"
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
    case .sport: return "sportscourt"
    case .collections: return "rectangle.stack"
    case .watching: return "play.tv"
    case .bookmarks: return "bookmark"
    case .history: return "clock.arrow.circlepath"
    case .downloads: return "arrow.down.circle"
    case .profile: return "person.crop.circle"
    }
  }
}
