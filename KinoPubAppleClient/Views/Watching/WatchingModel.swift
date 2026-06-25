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

@MainActor
class WatchingModel: ObservableObject {

  private var authState: AuthState
  private var errorHandler: ErrorHandler
  private var contentService: VideoContentService
  private var bag = Set<AnyCancellable>()

  @Published public var serials: [WatchingSerial] = []
  @Published public var isLoading: Bool = true
  @Published public var tab: WatchingTab = .newEpisodes
  @Published public var episodesType: WatchingEpisodesType = .serial

  init(itemsService: VideoContentService, authState: AuthState, errorHandler: ErrorHandler) {
    self.contentService = itemsService
    self.authState = authState
    self.errorHandler = errorHandler
    subscribeForReload()
  }

  func fetchItems() async {
    guard authState.userState == .authorized else {
      subscribeForAuth()
      return
    }

    isLoading = true
    do {
      let data: ArrayData<WatchingSerial>
      switch tab {
      case .newEpisodes:
        // New-episodes tab: unwatched serials with new episodes, narrowed by content type.
        data = try await contentService.fetchWatchingSerials(subscribed: 0, type: episodesType.rawValue)
      case .watchlist:
        // My-series tab: the full watchlist, all content types.
        data = try await contentService.fetchWatchingSerials(subscribed: 1, type: nil)
      }
      serials = data.items
      isLoading = false
    } catch {
      Logger.app.debug("fetch watching serials error: \(error)")
      isLoading = false
      errorHandler.setError(error)
    }
  }

  func select(tab: WatchingTab) {
    guard tab != self.tab else { return }
    self.tab = tab
  }

  func select(episodesType: WatchingEpisodesType) {
    guard episodesType != self.episodesType else { return }
    self.episodesType = episodesType
  }

  @Sendable @MainActor
  func refresh() async {
    errorHandler.reset()
    Logger.app.debug("refetch watching serials")
    await fetchItems()
  }

  // Refetch whenever the tab or the new-episodes content-type changes.
  private func subscribeForReload() {
    Publishers.Merge(
      $tab.removeDuplicates().map { _ in () },
      $episodesType.removeDuplicates().map { _ in () }
    )
    .dropFirst()
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
