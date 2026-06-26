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

/// Search result scope, mirroring the kino.pub web tabs: All / Titles / Actors / Directors.
enum SearchScope: String, CaseIterable, Identifiable {
  case all
  case title
  case cast
  case director

  var id: String { rawValue }

  var title: String {
    switch self {
    case .all: return "All"
    case .title: return "Titles"
    case .cast: return "Actors"
    case .director: return "Directors"
    }
  }

  /// The `field` query param for the search request (nil = match by title).
  var field: String? {
    switch self {
    case .all, .title: return nil
    case .cast: return "cast"
    case .director: return "director"
    }
  }
}

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
  /// Single-field result list used by the person-search screen (paginated). The main search bar
  /// uses the per-scope buckets below instead.
  @Published public var results: [MediaItem] = []
  /// Pagination for the current results query; drives load-more.
  private var pagination: Pagination?
  /// The query that the current `pagination`/`results` belong to.
  private var pagedQuery: String = ""

  // Main search bar: kino.pub-style scoped results (Titles / Actors / Directors) with counts.
  @Published public var titleResults: [MediaItem] = []
  @Published public var castResults: [MediaItem] = []
  @Published public var directorResults: [MediaItem] = []
  @Published public var scope: SearchScope = .all

  /// People (from TMDB) the current query matched, shown above the films on the Actors/Directors tabs.
  @Published public var matchedActors: [TMDBPerson] = []
  @Published public var matchedDirectors: [TMDBPerson] = []
  private let tmdbService: TMDBService = AppContext.shared.tmdbService

  /// Deduplicated union across all three scopes (skeletons excluded), for the "All" tab.
  public var allResults: [MediaItem] {
    var seen = Set<Int>()
    var out: [MediaItem] = []
    for item in titleResults + castResults + directorResults
    where !(item.skeleton ?? false) && seen.insert(item.id).inserted {
      out.append(item)
    }
    return out
  }

  public func results(for scope: SearchScope) -> [MediaItem] {
    switch scope {
    case .all: return allResults
    case .title: return titleResults
    case .cast: return castResults
    case .director: return directorResults
    }
  }

  public func count(for scope: SearchScope) -> Int {
    results(for: scope).filter { !($0.skeleton ?? false) }.count
  }
  @Published public var genres: [MediaGenre] = []
  @Published public var genrePosters: [Int: String] = [:]
  @Published public var genreResults: [MediaItem] = []
  @Published public var recentItems: [RecentSearchItem] = []
  @Published public var searching: Bool = false
  @Published public var browseLoading: Bool = false

  /// Optional search field ("cast" for actor, "director"); when set, results
  /// are searched against that field instead of the default title match.
  private var searchField: String?

  /// The query value that was last applied as a person-search preset. Used to
  /// distinguish a programmatic preset from a manual edit of the search bar.
  private var presetQuery: String?

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
        guard let self else { return }
        // The programmatic preset (person search) already ran the search in preset();
        // skip here to avoid a second skeleton flash.
        if value == self.presetQuery {
          return
        }
        // A manual edit of the search bar resets any preset person-search field
        // (so typing a regular title query searches by title again).
        self.searchField = nil
        self.presetQuery = nil
        Task { await self.performSearch(query: value) }
      }.store(in: &bag)
  }

  /// Presets a person search (actor/director). The query runs immediately against the given
  /// `field`. Used by the standalone person-search screen, which renders the single `results` list.
  func preset(query: String, field: String?) {
    presetQuery = query
    self.query = query
    Task { await performFieldSearch(query: query, field: field) }
  }

  /// Main search bar: query Titles / Actors / Directors at once so the UI can show tabs with
  /// per-scope counts (like the kino.pub web search).
  func performSearch(query: String) async {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      titleResults = []
      castResults = []
      directorResults = []
      pagedQuery = ""
      searching = false
      return
    }

    searching = true
    pagedQuery = trimmed
    titleResults = MediaItem.skeletonMock()
    castResults = []
    directorResults = []
    matchedActors = []
    matchedDirectors = []

    async let titles = contentService.search(query: trimmed, contentType: nil, field: nil, page: nil)
    async let cast = contentService.search(query: trimmed, contentType: nil, field: "cast", page: nil)
    async let directors = contentService.search(query: trimmed, contentType: nil, field: "director", page: nil)
    // Which actual people matched the query (for the circles above the Actors/Directors results).
    async let actorPeople = tmdbService.people(matching: trimmed, role: .acting)
    async let directorPeople = tmdbService.people(matching: trimmed, role: .directing)

    let t = (try? await titles)?.items ?? []
    let c = (try? await cast)?.items ?? []
    let d = (try? await directors)?.items ?? []
    let actors = await actorPeople
    let directorsFound = await directorPeople

    // Ignore stale responses if the query changed while the requests were in flight.
    guard trimmed == pagedQuery else { return }
    titleResults = t
    castResults = c
    directorResults = d
    matchedActors = actors
    matchedDirectors = directorsFound

    // If the current tab has nothing but another does, jump to the richest one (e.g. a pure actor
    // name has 0 titles but many "Actors" hits — show that tab, as the web does).
    if results(for: scope).isEmpty {
      if let best = [SearchScope.title, .cast, .director].max(by: { count(for: $0) < count(for: $1) }),
         count(for: best) > 0 {
        scope = best
      }
    }
    searching = false
  }

  /// Single-field search (Titles only, or a person field) feeding the paginated `results` list.
  func performFieldSearch(query: String, field: String?) async {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    searchField = field
    guard !trimmed.isEmpty else {
      results = []
      pagination = nil
      pagedQuery = ""
      searching = false
      return
    }

    searching = true
    results = MediaItem.skeletonMock()
    pagination = nil
    pagedQuery = trimmed

    do {
      let data = try await contentService.search(query: trimmed, contentType: nil, field: field, page: nil)
      guard trimmed == pagedQuery else { return }
      results = data.items
      pagination = data.pagination
    } catch {
      Logger.app.debug("search error: \(error)")
      results = []
      pagination = nil
      errorHandler.setError(error)
    }
    searching = false
  }

  /// Loads the next page when the last result becomes visible (mirrors
  /// `MediaCatalog.loadMoreContent`). Keeps it simple: no separate loading flag.
  func loadMoreContent(after item: MediaItem) {
    guard let pagination, pagination.current < pagination.total else { return }
    guard let last = results.last, last.id == item.id, !(item.skeleton ?? false) else { return }

    let nextPage = pagination.current + 1
    let trimmed = pagedQuery
    let field = searchField
    Task {
      do {
        let data = try await contentService.search(query: trimmed, contentType: nil, field: field, page: nextPage)
        // Guard against a query change while the page was in flight.
        guard pagedQuery == trimmed else { return }
        results.append(contentsOf: data.items)
        self.pagination = data.pagination
      } catch {
        Logger.app.debug("search load-more error: \(error)")
      }
    }
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
      genres = try await contentService.fetchGenres(type: nil)
    } catch {
      // Browse genres are supplementary (cards fall back to a gradient), so a failure here
      // must not throw a backend-error banner over the search screen on open.
      Logger.app.debug("fetch genres error: \(error)")
    }
    browseLoading = false
    // Genres render immediately; representative posters fill in asynchronously.
    Task { await loadGenrePosters() }
  }

  /// Loads one representative poster per genre (top-rated movie in that genre) so the Browse
  /// cards show real artwork instead of a flat gradient. Requests are bounded so we don't fire
  /// 20+ at once; failures are ignored and that genre simply falls back to the gradient.
  private func loadGenrePosters() async {
    let genresToLoad = genres.filter { genrePosters[$0.id] == nil }
    guard !genresToLoad.isEmpty else { return }

    let maxConcurrent = 4
    let service = contentService

    await withTaskGroup(of: (Int, String?).self) { group in
      var iterator = genresToLoad.makeIterator()
      var inFlight = 0

      func addTask(for genre: MediaGenre) {
        group.addTask {
          let filter = MediaItemsFilter(contentType: .movie,
                                        genres: [genre.id],
                                        countries: [],
                                        year: nil,
                                        age: nil,
                                        sort: "rating-")
          guard let data = try? await service.filter(filter: filter, page: nil),
                let first = data.items.first else {
            return (genre.id, nil)
          }
          return (genre.id, first.posters.wide ?? first.posters.medium)
        }
      }

      // Prime the group up to the concurrency cap.
      while inFlight < maxConcurrent, let genre = iterator.next() {
        addTask(for: genre)
        inFlight += 1
      }

      // As each result arrives, publish it and start the next genre to keep the cap full.
      while let (id, poster) = await group.next() {
        if let poster, !poster.isEmpty {
          genrePosters[id] = poster
        }
        if let genre = iterator.next() {
          addTask(for: genre)
        }
      }
    }
  }

  func loadGenreResults(genreId: Int) async {
    genreResults = MediaItem.skeletonMock()
    // A non-positive id means "no genre filter" (the MediaType fallback cards),
    // so we just browse the content type itself.
    let filter = MediaItemsFilter(contentType: .movie,
                                  genres: genreId > 0 ? [genreId] : [],
                                  countries: [],
                                  year: nil,
                                  age: nil,
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
