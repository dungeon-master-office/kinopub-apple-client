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
  }

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

  init(itemsService: VideoContentService, authState: AuthState, errorHandler: ErrorHandler) {
    self.itemsService = itemsService
    self.authState = authState
    self.errorHandler = errorHandler
  }

  func fetchData() async {
    guard authState.userState == .authorized else {
      subscribeForAuth()
      return
    }

    // The watch history powers the "Continue Watching" shelf. Fetch it alongside the other
    // shelves, but isolate failures so a history error can't take down the whole Home screen.
    async let history = itemsService.fetchHistory(page: nil)

    do {
      async let popularMovies = itemsService.fetch(shortcut: .popular, contentType: .movie, page: nil)
      async let hotSeries = itemsService.fetch(shortcut: .hot, contentType: .serial, page: nil)
      async let freshMovies = itemsService.fetch(shortcut: .fresh, contentType: .movie, page: nil)
      async let freshSeries = itemsService.fetch(shortcut: .fresh, contentType: .serial, page: nil)
      async let popularSeries = itemsService.fetch(shortcut: .popular, contentType: .serial, page: nil)
      async let hotMovies = itemsService.fetch(shortcut: .hot, contentType: .movie, page: nil)

      let loaded: [Shelf] = [
        Shelf(title: "Популярные фильмы", items: try await popularMovies.items, ranked: true),
        Shelf(title: "Горячие сериалы", items: try await hotSeries.items, ranked: true),
        Shelf(title: "Новинки кино", items: try await freshMovies.items, ranked: false),
        Shelf(title: "Свежие сериалы", items: try await freshSeries.items, ranked: false),
        Shelf(title: "Популярные сериалы", items: try await popularSeries.items, ranked: false),
        Shelf(title: "Горячее кино", items: try await hotMovies.items, ranked: false)
      ]

      shelves = loaded

      // Build the hero gallery from the lead item of each shelf (deduplicated), so the
      // top of Home is a swipeable carousel of varied features rather than a single title.
      var seen = Set<Int>()
      var featuredItems: [MediaItem] = []
      for shelf in loaded {
        if let first = shelf.items.first, !seen.contains(first.id) {
          seen.insert(first.id)
          featuredItems.append(first)
        }
      }
      featured = featuredItems
    } catch {
      Logger.app.debug("fetch home error: \(error)")
      errorHandler.setError(error)
    }

    // Best-effort: a history failure should never surface an error on Home.
    let recent = (try? await history)?.history.map { $0.item } ?? []
    // Deduplicate by id (a series shows up once), keep the most recent order.
    var seen = Set<Int>()
    let unique = recent.filter { seen.insert($0.id).inserted }
    let candidates = Array(unique.prefix(10))

    // Enrich each entry with its watch progress + last-watched episode (details carry the
    // per-episode watching positions that the history list does not).
    let service = itemsService
    let enriched: [ContinueItem] = await withTaskGroup(of: (Int, ContinueItem).self) { group in
      for (index, item) in candidates.enumerated() {
        group.addTask {
          let full = (try? await service.fetchDetails(for: "\(item.id)").item) ?? item
          return (index, HomeModel.continueItem(from: full))
        }
      }
      var slots = [ContinueItem?](repeating: nil, count: candidates.count)
      for await (index, value) in group { slots[index] = value }
      return slots.compactMap { $0 }
    }

    // Surface locally-started titles (> 10s) that the backend doesn't list yet, newest first.
    let backendIds = Set(enriched.map { $0.id })
    let localOnly = AppContext.shared.localProgressStore.allEntries()
      .filter { !backendIds.contains($0.id) }
      .map { entry -> ContinueItem in
        let subtitle: String?
        if let season = entry.season, let episode = entry.episode {
          subtitle = "S\(season) · E\(episode)"
        } else {
          subtitle = entry.item.duration.totalFormatted
        }
        return ContinueItem(id: entry.id, item: entry.item, progress: entry.progress, subtitle: subtitle)
      }

    continueWatching = localOnly + enriched
    continueWatchingLoading = false
  }

  /// Builds a Continue Watching entry from a fully-loaded media item.
  nonisolated private static func continueItem(from item: MediaItem) -> ContinueItem {
    if item.isSeries, let seasons = item.seasons,
       let target = lastWatchingEpisode(in: seasons) {
      let progress = target.episode.duration > 0
        ? min(max(Double(target.episode.watching.time) / Double(target.episode.duration), 0), 1)
        : nil
      let subtitle = "S\(target.season.number) · E\(target.episode.number)"
      return ContinueItem(id: item.id, item: item, progress: progress, subtitle: subtitle)
    }
    if let video = item.videos?.first, video.duration > 0, video.watching.time > 0 {
      let progress = min(max(Double(video.watching.time) / Double(video.duration), 0), 1)
      return ContinueItem(id: item.id, item: item, progress: progress, subtitle: item.duration.totalFormatted)
    }
    return ContinueItem(id: item.id, item: item, progress: nil, subtitle: item.duration.totalFormatted)
  }

  /// The most recent in-progress episode across all seasons.
  nonisolated private static func lastWatchingEpisode(in seasons: [Season]) -> (season: Season, episode: Episode)? {
    var best: (season: Season, episode: Episode)?
    for season in seasons {
      for episode in season.episodes where episode.watching.time > 0 {
        if let current = best {
          if (season.number, episode.number) > (current.season.number, current.episode.number) {
            best = (season, episode)
          }
        } else {
          best = (season, episode)
        }
      }
    }
    return best
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
