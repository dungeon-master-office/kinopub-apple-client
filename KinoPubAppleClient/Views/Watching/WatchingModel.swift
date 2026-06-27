//
//  WatchingModel.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 24.06.2026.
//

import Foundation
import KinoPubBackend
import OSLog
import KinoPubLogging
import Combine

// Top-level tabs of the "Watching" screen, mirroring kino.pub:
// - newEpisodes: serials with new (unwatched) episodes, with a content-type sub-filter
// - watchlist: the full list of subscribed serials ("My series")
enum WatchingTab: String, CaseIterable, Identifiable {
  case newEpisodes = "new"
  case watchlist

  var id: String { rawValue }

  var title: String {
    switch self {
    case .newEpisodes:
      return "New episodes"
    case .watchlist:
      return "My series"
    }
  }
}

// Content-type sub-tabs shown under "New episodes", mirroring the web
// /media/new-serial-episodes?type=serial|docuserial|tvshow.
enum WatchingEpisodesType: String, CaseIterable, Identifiable {
  case serial
  case docuserial
  case tvshow

  var id: String { rawValue }

  var mediaType: MediaType {
    switch self {
    case .serial: return .serial
    case .docuserial: return .docuserial
    case .tvshow: return .tvshow
    }
  }

  var title: String { mediaType.title }
}

// Content-kind sub-tabs shown under "Watching" / "Я смотрю": serials you're subscribed to
// (/v1/watching/serials?subscribed=1) vs movies you're part-way through (/v1/watching/movies).
enum WatchlistKind: String, CaseIterable, Identifiable {
  case serials
  case movies

  var id: String { rawValue }

  var title: String {
    switch self {
    case .serials: return "Series"
    case .movies: return "Movies"
    }
  }
}

@MainActor
class WatchingModel: ObservableObject {

  private var authState: AuthState
  private var errorHandler: ErrorHandler
  private var contentService: VideoContentService
  private var bag = Set<AnyCancellable>()

  @Published public var serials: [WatchingSerial] = []
  @Published public var isLoading: Bool = true
  /// Fixed for the lifetime of the screen — "New episodes" and "Watching" are now two separate
  /// top-level destinations rather than tabs inside one screen.
  public let tab: WatchingTab
  @Published public var episodesType: WatchingEpisodesType = .serial
  /// Serials vs movies sub-filter for the "Watching" / "Я смотрю" tab.
  @Published public var watchlistKind: WatchlistKind = .serials

  init(itemsService: VideoContentService,
       authState: AuthState,
       errorHandler: ErrorHandler,
       tab: WatchingTab = .newEpisodes) {
    self.contentService = itemsService
    self.authState = authState
    self.errorHandler = errorHandler
    self.tab = tab
    subscribeForReload()
    // Load as soon as the model exists, decoupled from the view's `.task` (which doesn't reliably
    // fire across the compact ↔ regular split-view transition / the sidebar detail's nested stack).
    // `fetchItems` no-ops until authorized and retries via `subscribeForAuth`.
    Task { await fetchItems() }
  }

  func fetchItems() async {
    guard authState.userState == .authorized else {
      subscribeForAuth()
      return
    }

    isLoading = true
    do {
      switch tab {
      case .newEpisodes:
        // New-episodes tab: unwatched serials with new episodes, narrowed by content type. The
        // kino.pub endpoint ignores the `type` query param (returns all types regardless), so the
        // sub-tab filter has to be applied on the client by the item's `type`.
        let data = try await contentService.fetchWatchingSerials(subscribed: 0, type: episodesType.rawValue)
        serials = data.items.filter { $0.type == episodesType.rawValue }
      case .watchlist:
        // "Я смотрю": serials you're subscribed to, or movies you're part-way through.
        switch watchlistKind {
        case .serials:
          let data = try await contentService.fetchWatchingSerials(subscribed: 1, type: nil)
          serials = data.items
        case .movies:
          let data = try await contentService.fetchWatchingMovies()
          serials = data.items
        }
      }
      isLoading = false
    } catch {
      Logger.app.debug("fetch watching serials error: \(error)")
      isLoading = false
      errorHandler.setError(error)
    }
  }

  func select(episodesType: WatchingEpisodesType) {
    guard episodesType != self.episodesType else { return }
    self.episodesType = episodesType
  }

  func select(watchlistKind: WatchlistKind) {
    guard watchlistKind != self.watchlistKind else { return }
    self.watchlistKind = watchlistKind
  }

  @Sendable @MainActor
  func refresh() async {
    errorHandler.reset()
    Logger.app.debug("refetch watching serials")
    await fetchItems()
  }

  // Refetch whenever the new-episodes content-type sub-tab or the watchlist serials/movies sub-tab changes.
  private func subscribeForReload() {
    // Each @Published fires its current value on subscribe, so drop both initial emissions.
    Publishers.Merge($episodesType.map { _ in () }, $watchlistKind.map { _ in () })
      .dropFirst(2)
      .sink { [weak self] _ in
        self?.serials = []
        Task { await self?.fetchItems() }
      }
      .store(in: &bag)
  }

  private func subscribeForAuth() {
    authState.$userState.filter({ $0 == .authorized }).first().sink { [weak self] _ in
      Task {
        await self?.refresh()
      }
    }.store(in: &bag)
  }

}
