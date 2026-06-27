//
//  HomeModel.swift
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
class HomeModel: ObservableObject {

  struct Shelf: Identifiable {
    let id = UUID()
    let title: String
    let items: [MediaItem]
    let ranked: Bool
    /// The catalog filter this shelf represents, so its header can open the full list.
    var filter: MediaItemsFilter? = nil
  }

  /// Definition of a Home shelf (matches the kino.pub web sections).
  private struct ShelfSpec {
    let title: String
    let type: MediaType
    let sort: String
    let period: String?

    var filter: MediaItemsFilter {
      var f = MediaItemsFilter(contentType: type, genres: [], countries: [], year: nil, age: nil, sort: sort)
      f.period = period
      return f
    }
  }

  // Mirrors the kino.pub web home sections (type + order + period). Web order → API sort:
  // views → views-, added → created-, watchers → watchers-. `period` is sent server-side
  // (see FilterItemsRequest); "Популярные фильмы" = most viewed this month.
  private static let shelfSpecs: [ShelfSpec] = [
    ShelfSpec(title: "Популярные фильмы", type: .movie, sort: "views-", period: "month"),
    ShelfSpec(title: "Новые фильмы", type: .movie, sort: "created-", period: nil),
    ShelfSpec(title: "Популярные сериалы", type: .serial, sort: "watchers-", period: nil),
    ShelfSpec(title: "Новые сериалы", type: .serial, sort: "created-", period: nil),
    ShelfSpec(title: "Новые концерты", type: .concert, sort: "created-", period: nil),
    ShelfSpec(title: "Новое в 3D", type: .threeD, sort: "created-", period: nil),
    ShelfSpec(title: "Новые ДокуФильмы", type: .documovie, sort: "created-", period: nil),
    ShelfSpec(title: "Новые Докусериалы", type: .docuserial, sort: "created-", period: nil),
    ShelfSpec(title: "Новые ТВ шоу", type: .tvshow, sort: "created-", period: nil)
  ]

  /// A "Continue Watching" entry enriched with resume progress and, for series,
  /// the last episode the user was watching.
  struct ContinueItem: Identifiable {
    let id: Int
    let item: MediaItem
    let progress: Double?
    let subtitle: String?
  }

  private var authState: AuthState
  private var errorHandler: ErrorHandler
  private var itemsService: VideoContentService
  private var bag = Set<AnyCancellable>()

  @Published public var shelves: [Shelf] = HomeModel.skeletonShelves()
  @Published public var featured: [MediaItem] = []
  @Published public var continueWatching: [ContinueItem] = []
  /// True until the Continue Watching row has resolved, so the UI can reserve its space.
  @Published public var continueWatchingLoading: Bool = true
  /// Whether the real shelves have been fetched. `shelves` starts as skeleton placeholders (so
  /// it's never empty), so we can't gate the one-time load on `shelves.isEmpty`.
  private var didLoadShelves = false

  init(itemsService: VideoContentService, authState: AuthState, errorHandler: ErrorHandler) {
    self.itemsService = itemsService
    self.authState = authState
    self.errorHandler = errorHandler
    // Load when the model is created, not on the view's `.task` (which doesn't reliably fire in a
    // compact split view / nested navigation stack). `fetchData` is idempotent + auth-gated.
    Task { await fetchData() }
  }

  func fetchData() async {
    guard authState.userState == .authorized else {
      subscribeForAuth()
      return
    }

    // The watch history powers the "Continue Watching" shelf. Fetch it alongside the other
    // shelves, but isolate failures so a history error can't take down the whole Home screen.
    async let history = itemsService.fetchHistory(page: nil)

    // Build the shelves from the kino.pub web sections (each with its own order/period),
    // fetched in parallel. A failed shelf is simply dropped rather than failing the screen.
    // Only build them once: returning from a pushed detail must not rebuild the list (which
    // would reset the scroll position). Pull-to-refresh goes through `refresh()` instead.
    if !didLoadShelves {
      let specs = HomeModel.shelfSpecs
      let shelfService = itemsService
      let loaded: [Shelf] = await withTaskGroup(of: (Int, Shelf?).self) { group in
        for (index, spec) in specs.enumerated() {
          group.addTask {
            let items = (try? await shelfService.filter(filter: spec.filter, page: nil))?.items ?? []
            let shelf = items.isEmpty ? nil
              : Shelf(title: spec.title, items: items, ranked: false, filter: spec.filter)
            return (index, shelf)
          }
        }
        var slots = [Shelf?](repeating: nil, count: specs.count)
        for await (index, shelf) in group { slots[index] = shelf }
        return slots.compactMap { $0 }
      }

      // Only commit (and stop reloading) once something actually came back, so a transient
      // failure keeps the skeletons and retries on the next appearance instead of sticking empty.
      if !loaded.isEmpty {
        didLoadShelves = true
        shelves = loaded

        // Build the hero gallery from the lead item of each shelf (deduplicated), so the
        // top of Home is a swipeable carousel of varied features rather than a single title.
        var heroSeen = Set<Int>()
        var featuredItems: [MediaItem] = []
        for shelf in loaded {
          if let first = shelf.items.first, !heroSeen.contains(first.id) {
            heroSeen.insert(first.id)
            featuredItems.append(first)
          }
        }
        featured = featuredItems
      }
    }

    // Best-effort: a history failure should never surface an error on Home.
    let historyEntries = (try? await history)?.history ?? []
    // Deduplicate by id (a series shows up once), keeping the most-recent occurrence and its
    // real "last watched" timestamp so we can order against locally-tracked items below.
    var seen = Set<Int>()
    let uniqueHistory: [(item: MediaItem, watchedAt: TimeInterval)] = historyEntries.compactMap { entry in
      guard seen.insert(entry.item.id).inserted else { return nil }
      return (entry.item, entry.lastSeen ?? entry.time ?? entry.firstSeen ?? 0)
    }
    let candidates = Array(uniqueHistory.prefix(10))

    // Enrich each entry with its watch progress + last-watched episode (details carry the
    // per-episode watching positions that the history list does not), keeping the timestamp.
    let service = itemsService
    let enriched: [(item: ContinueItem, watchedAt: TimeInterval)] = await withTaskGroup(of: (Int, ContinueItem).self) { group in
      for (index, candidate) in candidates.enumerated() {
        group.addTask {
          let full = (try? await service.fetchDetails(for: "\(candidate.item.id)").item) ?? candidate.item
          return (index, HomeModel.continueItem(from: full))
        }
      }
      var slots = [ContinueItem?](repeating: nil, count: candidates.count)
      for await (index, value) in group { slots[index] = value }
      return slots.enumerated().compactMap { index, item in
        item.map { ($0, candidates[index].watchedAt) }
      }
    }

    // Locally-started titles (> 10s) the backend doesn't list yet, with their own update time.
    let backendIds = Set(enriched.map { $0.item.id })
    let localOnly: [(item: ContinueItem, watchedAt: TimeInterval)] = AppContext.shared.localProgressStore.allEntries()
      .filter { !backendIds.contains($0.id) }
      .map { entry in
        let subtitle: String?
        if let season = entry.season, let episode = entry.episode {
          subtitle = "S\(season) · E\(episode)"
        } else {
          subtitle = entry.item.duration.totalFormatted
        }
        let item = ContinueItem(id: entry.id, item: entry.item, progress: entry.progress, subtitle: subtitle)
        return (item, entry.updatedAt)
      }

    // Single list ordered by real recency (newest first) across both sources, so Continue Watching
    // matches what History shows instead of always floating local items to the front.
    continueWatching = (enriched + localOnly).sorted { $0.watchedAt > $1.watchedAt }.map { $0.item }
    continueWatchingLoading = false
  }

  /// Builds a Continue Watching entry from a fully-loaded media item. Series use the same
  /// `MediaItem.continueEpisode()` logic as the detail page so the two stay in sync (DRY).
  nonisolated private static func continueItem(from item: MediaItem) -> ContinueItem {
    if item.isSeries, let target = item.continueEpisode() ?? item.orderedEpisodes.last {
      let episode = target.episode
      let progress: Double? = (episode.duration > 0 && episode.watching.time > 0)
        ? min(max(Double(episode.watching.time) / Double(episode.duration), 0), 1)
        : nil
      return ContinueItem(id: item.id, item: item, progress: progress,
                          subtitle: "S\(target.season.number) · E\(episode.number)")
    }
    if let video = item.videos?.first, video.duration > 0, video.watching.time > 0 {
      let progress = min(max(Double(video.watching.time) / Double(video.duration), 0), 1)
      return ContinueItem(id: item.id, item: item, progress: progress, subtitle: item.duration.totalFormatted)
    }
    return ContinueItem(id: item.id, item: item, progress: nil, subtitle: item.duration.totalFormatted)
  }

  private static func skeletonShelves() -> [Shelf] {
    [
      Shelf(title: "Популярные фильмы", items: MediaItem.skeletonMock(), ranked: true),
      Shelf(title: "Горячие сериалы", items: MediaItem.skeletonMock(), ranked: true),
      Shelf(title: "Новинки кино", items: MediaItem.skeletonMock(), ranked: false)
    ]
  }

  private func subscribeForAuth() {
    authState.$userState.filter({ $0 == .authorized }).first().sink { [weak self] _ in
      Task {
        await self?.fetchData()
      }
    }.store(in: &bag)
  }

}
