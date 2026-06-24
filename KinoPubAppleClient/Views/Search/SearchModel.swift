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

@MainActor
class SearchModel: ObservableObject {

  private static let recentSearchesKey = "recentSearches"
  private static let recentSearchesLimit = 8

  private var authState: AuthState
  private var errorHandler: ErrorHandler
  private var contentService: VideoContentService
  private var bag = Set<AnyCancellable>()

  @Published public var query: String = ""
  @Published public var results: [MediaItem] = []
  @Published public var genres: [MediaGenre] = []
  @Published public var genreResults: [MediaItem] = []
  @Published public var recentSearches: [String] = []
  @Published public var searching: Bool = false
  @Published public var browseLoading: Bool = false

  init(itemsService: VideoContentService, authState: AuthState, errorHandler: ErrorHandler) {
    self.contentService = itemsService
    self.authState = authState
    self.errorHandler = errorHandler
    self.recentSearches = Self.loadRecentSearches()
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
      addRecentSearch(trimmed)
    } catch {
      Logger.app.debug("search error: \(error)")
      results = []
      errorHandler.setError(error)
    }
    searching = false
  }

  // MARK: - Recent searches

  func addRecentSearch(_ query: String) {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    var updated = recentSearches.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
    updated.insert(trimmed, at: 0)
    if updated.count > Self.recentSearchesLimit {
      updated = Array(updated.prefix(Self.recentSearchesLimit))
    }
    recentSearches = updated
    UserDefaults.standard.set(updated, forKey: Self.recentSearchesKey)
  }

  func clearRecents() {
    recentSearches = []
    UserDefaults.standard.removeObject(forKey: Self.recentSearchesKey)
  }

  private static func loadRecentSearches() -> [String] {
    UserDefaults.standard.stringArray(forKey: recentSearchesKey) ?? []
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
