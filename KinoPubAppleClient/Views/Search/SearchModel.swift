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

/// A person surfaced from a search, shown as a circle in "Cast & Crew". A person can be both an
/// actor and a director (e.g. Jackie Chan), so both roles are tracked and shown together.
struct SearchPerson: Identifiable, Hashable {
  let name: String   // canonical name as stored by kino.pub (correct casing)
  let isActor: Bool
  let isDirector: Bool
  var id: String { name }
  var displayName: String { name }

  /// Field used to open their filmography (acting is usually the larger set).
  var searchField: String { isActor ? "cast" : "director" }

  var roleLabel: String {
    switch (isActor, isDirector) {
    case (true, true): return "\("Actor".localized) · \("Director".localized)"
    case (false, true): return "Director".localized
    default: return "Actor".localized
    }
  }
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

  // MARK: - Apple-TV-style section buckets (committed search)

  /// Movies bucket (everything that isn't a series), preserving relevance order.
  public var movieResults: [MediaItem] { allResults.filter { !$0.isSeries } }
  /// TV Shows bucket (series), preserving relevance order.
  public var tvResults: [MediaItem] { allResults.filter { $0.isSeries } }
  /// The strongest matches across all buckets (title matches first) for the "Top Results" row.
  public var topResults: [MediaItem] { Array(allResults.prefix(6)) }

  /// People surfaced when the query matches an actor/director field. kino.pub returns films (not
  /// person entities), so we recover the person's CANONICAL name from the matched films' cast/
  /// director field (correct casing/spelling) — important so the avatar CDN lookup (md5 of the name)
  /// actually resolves, and so the displayed name looks right. Tapping a circle opens their films.
  public var people: [SearchPerson] {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard q.count >= 3 else { return [] }

    let actors = rankedNames(query: q, field: "cast", in: castResults)
    let directors = rankedNames(query: q, field: "director", in: directorResults)
    let directorKeys = Set(directors.map { $0.lowercased() })

    var result: [SearchPerson] = []
    var seen = Set<String>()
    // Actors first (usually the larger, more relevant set); flag dual-role where the same name also
    // directs. Then any directors not already listed.
    for name in actors {
      let key = name.lowercased()
      guard seen.insert(key).inserted else { continue }
      result.append(SearchPerson(name: name, isActor: true, isDirector: directorKeys.contains(key)))
    }
    for name in directors where !seen.contains(name.lowercased()) {
      seen.insert(name.lowercased())
      result.append(SearchPerson(name: name, isActor: false, isDirector: true))
    }
    return result
  }

  /// Distinct person names (canonical casing as stored by kino.pub) that match the query inside the
  /// items' cast/director field, ordered by how many matched titles credit them (most prolific
  /// first). kino.pub returns films, not person entities, so we mine the credits — e.g. query "джеки"
  /// → ["Джеки Чан", "Джеки Уивер", …].
  private func rankedNames(query q: String, field: String, in items: [MediaItem]) -> [String] {
    var order: [String] = []          // first-seen order of lowercased keys
    var canonical: [String: String] = [:]
    var counts: [String: Int] = [:]
    for item in items where !(item.skeleton ?? false) {
      let raw = field == "director" ? item.director : item.cast
      for piece in raw.split(separator: ",") {
        let name = piece.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.lowercased().contains(q) else { continue }
        let key = name.lowercased()
        if canonical[key] == nil { canonical[key] = name; order.append(key) }
        counts[key, default: 0] += 1
      }
    }
    return order.sorted { (counts[$0] ?? 0) > (counts[$1] ?? 0) }.map { canonical[$0] ?? $0 }
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
    // kino.pub's search needs at least 3 characters; below that we keep the live suggestions only
    // and don't hit the API (avoids empty/erroring requests on every keystroke).
    guard trimmed.count >= 3 else {
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

    async let titles = contentService.search(query: trimmed, contentType: nil, field: nil, page: nil)
    // Cast/director via the reliable cast=/director= FILTER (the search?field=cast full-text match
    // misses most actors/directors).
    async let cast = contentService.itemsByPerson(name: trimmed, field: "cast", page: nil)
    async let directors = contentService.itemsByPerson(name: trimmed, field: "director", page: nil)

    let t = (try? await titles)?.items ?? []
    let c = (try? await cast)?.items ?? []
    let d = (try? await directors)?.items ?? []

    // Ignore stale responses if the query changed while the requests were in flight.
    guard trimmed == pagedQuery else { return }
    titleResults = t
    castResults = c
    directorResults = d

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
      // Person screens (actor/director) use the reliable cast=/director= filter; plain title searches
      // keep using the search endpoint.
      let data: PaginatedData<MediaItem>
      if let field, field == "cast" || field == "director" {
        data = try await contentService.itemsByPerson(name: trimmed, field: field, page: nil)
      } else {
        data = try await contentService.search(query: trimmed, contentType: nil, field: field, page: nil)
      }
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
        let data: PaginatedData<MediaItem>
        if let field, field == "cast" || field == "director" {
          data = try await contentService.itemsByPerson(name: trimmed, field: field, page: nextPage)
        } else {
          data = try await contentService.search(query: trimmed, contentType: nil, field: field, page: nextPage)
        }
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
