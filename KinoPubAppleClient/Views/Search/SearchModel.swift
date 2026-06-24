//
//  SearchModel.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 24.06.2026.
//

import Foundation
import KinoPubBackend
import OSLog
import KinoPubLogging
import Combine

/// A recently opened search result, shown as a card in the "Recent" section.
struct RecentSearchItem: Codable, Identifiable, Hashable {
  let id: Int
  let title: String
  let subtitle: String
  let poster: String
}

@MainActor
class SearchModel: ObservableObject {

  private static let recentSearchesKey = "recentSearchItems"
  private static let recentSearchesLimit = 12

  private var authState: AuthState
  private var errorHandler: ErrorHandler
  private var contentService: VideoContentService
  private var bag = Set<AnyCancellable>()

  @Published public var query: String = ""
  @Published public var results: [MediaItem] = []
  @Published public var genres: [MediaGenre] = []
  @Published public var genreResults: [MediaItem] = []
  @Published public var recentItems: [RecentSearchItem] = []
  @Published public var searching: Bool = false
  @Published public var browseLoading: Bool = false

  init(itemsService: VideoContentService, authState: AuthState, errorHandler: ErrorHandler) {
    self.contentService = itemsService
    self.authState = authState
    self.errorHandler = errorHandler
    self.recentItems = Self.loadRecentItems()
    subscribe()
  }

  // MARK: - Search

  private func subscribe() {
    $query
      .dropFirst()
      .removeDuplicates()
      .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
      .sink { [weak self] value in
        Task { await self?.performSearch(query: value) }
      }.store(in: &bag)
  }

  func performSearch(query: String) async {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      results = []
      searching = false
      return
    }

    searching = true
    results = MediaItem.skeletonMock()

    do {
      let data = try await contentService.search(query: trimmed, page: nil)
      results = data.items
    } catch {
      Logger.app.debug("search error: \(error)")
      results = []
      errorHandler.setError(error)
    }
    searching = false
  }

  // MARK: - Recent searches

  /// Records an opened result so it appears in "Recent" (mirrors the Apple TV app, which lists
  /// recently opened titles with their artwork rather than raw query strings).
  func recordRecent(_ item: MediaItem) {
    let subtitle = MediaType(rawValue: item.type)?.title ?? item.type.capitalized
    let recent = RecentSearchItem(id: item.id,
                                  title: item.localizedTitle,
                                  subtitle: subtitle,
                                  poster: item.posters.medium)
    var updated = recentItems.filter { $0.id != recent.id }
    updated.insert(recent, at: 0)
    if updated.count > Self.recentSearchesLimit {
      updated = Array(updated.prefix(Self.recentSearchesLimit))
    }
    recentItems = updated
    persistRecents()
  }

  func clearRecents() {
    recentItems = []
    UserDefaults.standard.removeObject(forKey: Self.recentSearchesKey)
  }

  private func persistRecents() {
    if let data = try? JSONEncoder().encode(recentItems) {
      UserDefaults.standard.set(data, forKey: Self.recentSearchesKey)
    }
  }

  private static func loadRecentItems() -> [RecentSearchItem] {
    guard let data = UserDefaults.standard.data(forKey: recentSearchesKey),
          let items = try? JSONDecoder().decode([RecentSearchItem].self, from: data) else {
      return []
    }
    return items
  }

  // MARK: - Browse / genres

  func loadGenres() async {
    guard genres.isEmpty else { return }
    browseLoading = true
    do {
      genres = try await contentService.fetchGenres()
    } catch {
      Logger.app.debug("fetch genres error: \(error)")
      errorHandler.setError(error)
    }
    browseLoading = false
  }

  func loadGenreResults(genreId: Int) async {
    genreResults = MediaItem.skeletonMock()
    // A non-positive id means "no genre filter" (the MediaType fallback cards),
    // so we just browse the content type itself.
    let filter = MediaItemsFilter(contentType: .movie,
                                  genres: genreId > 0 ? [genreId] : [],
                                  countries: [],
                                  year: nil,
                                  sort: nil)
    do {
      let data = try await contentService.filter(filter: filter, page: nil)
      genreResults = data.items
    } catch {
      Logger.app.debug("fetch genre results error: \(error)")
      genreResults = []
      errorHandler.setError(error)
    }
  }

}
