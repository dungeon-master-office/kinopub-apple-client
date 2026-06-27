//
//  Routes.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 31.07.2023.
//

import Foundation
import KinoPubBackend

/// A single navigation route type shared by every section's `NavigationStack`.
///
/// Using one element type across all detail stacks is what keeps `NavigationSplitView` happy:
/// when the sidebar swaps the detail column from one section's stack to another, SwiftUI
/// reconciles the column's path against the new one. If the two stacks had *different* path
/// element types it traps with `AnyNavigationPath.Error.comparisonTypeMismatch`. With a single
/// `Route` type the comparison always succeeds, so no per-selection `.id` hack is needed.
enum Route: Hashable {
  case details(MediaItem)
  /// Open a media detail by id (used where only the id is known, e.g. the watching list).
  case detailsByID(Int)
  case seasons([Season])
  case season(Season)
  case player(any PlayableItem)
  case trailerPlayer(any PlayableItem)
  /// A filtered catalog (genre/country/year/etc.) opened from a detail page.
  case filteredCatalog(MediaItemsFilter, String)
  /// A person search (actor/director): (query, field, title).
  case personSearch(String, String, String)
  /// A genre browse grid: (genreId, title). genreId 0 means "all of this section".
  case genre(Int, String)
  case bookmark(Bookmark)
  case collection(Collection)
  /// A "see all" grid of already-loaded items (a search section opened in full): (items, title).
  case mediaList([MediaItem], String)
  /// A "see all" grid of people surfaced from a search (Cast & Crew): (people, title). Tapping a
  /// person opens their filmography, like the Cast & Crew on a film page / Apple TV.
  case castCrew([SearchPerson], String)

  func hash(into hasher: inout Hasher) {
    switch self {
    case .details(let item):
      hasher.combine(0); hasher.combine(item)
    case .detailsByID(let id):
      hasher.combine(1); hasher.combine(id)
    case .seasons(let seasons):
      hasher.combine(2); hasher.combine(seasons)
    case .season(let season):
      hasher.combine(3); hasher.combine(season)
    case .player(let item):
      hasher.combine(4); hasher.combine(item.id)
    case .trailerPlayer(let item):
      hasher.combine(5); hasher.combine(item.id)
    case .filteredCatalog(let filter, let title):
      hasher.combine(6); hasher.combine(filter); hasher.combine(title)
    case .personSearch(let query, let field, let title):
      hasher.combine(7); hasher.combine(query); hasher.combine(field); hasher.combine(title)
    case .genre(let id, let title):
      hasher.combine(8); hasher.combine(id); hasher.combine(title)
    case .bookmark(let bookmark):
      hasher.combine(9); hasher.combine(bookmark)
    case .collection(let collection):
      hasher.combine(10); hasher.combine(collection)
    case .mediaList(let items, let title):
      hasher.combine(11); hasher.combine(items); hasher.combine(title)
    case .castCrew(let people, let title):
      hasher.combine(12); hasher.combine(people); hasher.combine(title)
    }
  }

  static func == (lhs: Route, rhs: Route) -> Bool {
    lhs.hashValue == rhs.hashValue
  }
}
