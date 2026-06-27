//
//  CollectionDetailModel.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 24.06.2026.
//

import Foundation
import KinoPubBackend
import OSLog
import KinoPubLogging

/// Client-side sort for an already-loaded list of media items (used where the API can't sort for us:
/// a single collection's items, an actor's/director's filmography opened from a detail page, etc.).
enum MediaItemsSort: CaseIterable, Identifiable {
  case `default`
  case title
  case year
  case rating

  var id: Self { self }

  var localizedTitle: String {
    switch self {
    case .default: return "Default".localized
    case .title: return "Title".localized
    case .year: return "Year".localized
    case .rating: return "Rating".localized
    }
  }

  /// Returns `items` sorted by this option (`.default` keeps the original order).
  func sorted(_ items: [MediaItem]) -> [MediaItem] {
    switch self {
    case .default:
      return items
    case .title:
      return items.sorted { $0.localizedTitle.localizedCaseInsensitiveCompare($1.localizedTitle) == .orderedAscending }
    case .year:
      return items.sorted { $0.year > $1.year }
    case .rating:
      return items.sorted { ($0.kinopoiskRating ?? $0.imdbRating ?? 0) > ($1.kinopoiskRating ?? $1.imdbRating ?? 0) }
    }
  }
}

@MainActor
class CollectionDetailModel: ObservableObject {

  private var errorHandler: ErrorHandler
  private var collectionsService: CollectionsService

  /// The collection metadata. Replaced with the richer payload once the detail loads.
  @Published public var collection: Collection

  @Published public var items: [MediaItem] = []
  @Published public var isLoading: Bool = true
  @Published public var selectedSort: MediaItemsSort = .default {
    didSet { applySort() }
  }

  /// The unsorted items as returned by the API; `items` is the sorted view of this.
  private var rawItems: [MediaItem] = []

  init(collection: Collection, collectionsService: CollectionsService, errorHandler: ErrorHandler) {
    self.collection = collection
    self.collectionsService = collectionsService
    self.errorHandler = errorHandler
  }

  /// The films count to show in the header: prefer the API meta, fall back to loaded items.
  var itemsCountText: Int {
    collection.itemsCount ?? rawItems.count
  }

  func fetchItems() async {
    isLoading = true
    do {
      let result = try await collectionsService.fetchCollection(id: collection.id)
      // The view payload carries richer meta than the list payload; adopt it.
      collection = result.0
      rawItems = result.1
      applySort()
    } catch {
      Logger.app.debug("fetch collection items error: \(error)")
      errorHandler.setError(error)
    }
    isLoading = false
  }

  private func applySort() {
    items = selectedSort.sorted(rawItems)
  }

  @Sendable @MainActor
  func refresh() async {
    errorHandler.reset()
    await fetchItems()
  }

}
