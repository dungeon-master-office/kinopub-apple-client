//
//  NavigationLinkProvider.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 31.07.2023.
//

import Foundation
import KinoPubBackend

protocol NavigationLinkProvider {
  func link(for item: MediaItem) -> any Hashable
  func player(for item: any PlayableItem) -> any Hashable
  func trailerPlayer(for item: any PlayableItem) -> any Hashable
  func seasons(for seasons: [Season]) -> any Hashable
  func season(for season: Season) -> any Hashable
  /// A filtered catalog (genre/country/year/etc.) opened from a detail page.
  func filteredCatalog(filter: MediaItemsFilter, title: String) -> (any Hashable)?
  /// A person search (actor/director) opened from a detail page.
  func personSearch(query: String, field: String, title: String) -> (any Hashable)?
}

extension NavigationLinkProvider {
  func filteredCatalog(filter: MediaItemsFilter, title: String) -> (any Hashable)? { nil }
  func personSearch(query: String, field: String, title: String) -> (any Hashable)? { nil }
}

struct SearchRoutesLinkProvider: NavigationLinkProvider {
  func link(for item: MediaItem) -> any Hashable {
    SearchRoutes.details(item)
  }

  func player(for item: any PlayableItem) -> any Hashable {
    SearchRoutes.player(item)
  }

  func trailerPlayer(for item: any PlayableItem) -> any Hashable {
    SearchRoutes.trailerPlayer(item)
  }

  func seasons(for seasons: [Season]) -> any Hashable {
    SearchRoutes.seasons(seasons)
  }

  func season(for season: Season) -> any Hashable {
    SearchRoutes.season(season)
  }

  func filteredCatalog(filter: MediaItemsFilter, title: String) -> (any Hashable)? {
    SearchRoutes.filteredCatalog(filter, title)
  }

  func personSearch(query: String, field: String, title: String) -> (any Hashable)? {
    SearchRoutes.personSearch(query, field, title)
  }
}

struct MainRoutesLinkProvider: NavigationLinkProvider {
  func link(for item: MediaItem) -> any Hashable {
    MainRoutes.details(item)
  }
  
  func player(for item: any PlayableItem) -> any Hashable {
    MainRoutes.player(item)
  }
  
  func trailerPlayer(for item: any PlayableItem) -> any Hashable {
    MainRoutes.trailerPlayer(item)
  }
  
  func seasons(for seasons: [Season]) -> any Hashable {
    MainRoutes.seasons(seasons)
  }
  
  func season(for season: Season) -> any Hashable {
    MainRoutes.season(season)
  }

  func filteredCatalog(filter: MediaItemsFilter, title: String) -> (any Hashable)? {
    MainRoutes.filteredCatalog(filter, title)
  }

  func personSearch(query: String, field: String, title: String) -> (any Hashable)? {
    MainRoutes.personSearch(query, field, title)
  }
}

struct BookmarksRoutesLinkProvider: NavigationLinkProvider {
  func link(for item: MediaItem) -> any Hashable {
    BookmarksRoutes.details(item)
  }
  
  func player(for item: any PlayableItem) -> any Hashable {
    BookmarksRoutes.player(item)
  }
  
  func trailerPlayer(for item: any PlayableItem) -> any Hashable {
    BookmarksRoutes.trailerPlayer(item)
  }
  
  func seasons(for seasons: [Season]) -> any Hashable {
    BookmarksRoutes.seasons(seasons)
  }
  
  func season(for season: Season) -> any Hashable {
    BookmarksRoutes.season(season)
  }
}

struct HistoryRoutesLinkProvider: NavigationLinkProvider {
  func link(for item: MediaItem) -> any Hashable {
    HistoryRoutes.details(item)
  }

  func player(for item: any PlayableItem) -> any Hashable {
    HistoryRoutes.player(item)
  }

  func trailerPlayer(for item: any PlayableItem) -> any Hashable {
    HistoryRoutes.trailerPlayer(item)
  }

  func seasons(for seasons: [Season]) -> any Hashable {
    HistoryRoutes.seasons(seasons)
  }

  func season(for season: Season) -> any Hashable {
    HistoryRoutes.season(season)
  }
}

struct WatchingRoutesLinkProvider: NavigationLinkProvider {
  func link(for item: MediaItem) -> any Hashable {
    WatchingRoutes.details(item.id)
  }

  func player(for item: any PlayableItem) -> any Hashable {
    WatchingRoutes.player(item)
  }

  func trailerPlayer(for item: any PlayableItem) -> any Hashable {
    WatchingRoutes.trailerPlayer(item)
  }

  func seasons(for seasons: [Season]) -> any Hashable {
    WatchingRoutes.seasons(seasons)
  }

  func season(for season: Season) -> any Hashable {
    WatchingRoutes.season(season)
  }
}

struct CollectionsRoutesLinkProvider: NavigationLinkProvider {
  func link(for item: MediaItem) -> any Hashable {
    CollectionsRoutes.details(item)
  }

  func player(for item: any PlayableItem) -> any Hashable {
    CollectionsRoutes.player(item)
  }

  func trailerPlayer(for item: any PlayableItem) -> any Hashable {
    CollectionsRoutes.trailerPlayer(item)
  }

  func seasons(for seasons: [Season]) -> any Hashable {
    CollectionsRoutes.seasons(seasons)
  }

  func season(for season: Season) -> any Hashable {
    CollectionsRoutes.season(season)
  }
}

struct DownloadsRoutesLinkProvider: NavigationLinkProvider {
  func link(for item: MediaItem) -> any Hashable {
    BookmarksRoutes.details(item)
  }
  
  func player(for item: any PlayableItem) -> any Hashable {
    DownloadsRoutes.player(item)
  }
  
  func trailerPlayer(for item: any PlayableItem) -> any Hashable {
    DownloadsRoutes.trailerPlayer(item)
  }
  
  func seasons(for seasons: [Season]) -> any Hashable {
    ""
  }
  
  func season(for season: Season) -> any Hashable {
    ""
  }
}
