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

enum WatchingFilter: Int, CaseIterable, Identifiable {
  // Declaration order drives `allCases` (and thus the segmented control order):
  // "My Series" first, "New Episodes" second. Raw values stay fixed so they keep
  // mapping to the `subscribed` API parameter (watchlist = 1, newEpisodes = 0).
  case watchlist = 1
  case newEpisodes = 0

  var id: Int { rawValue }

  var title: String {
    switch self {
    case .newEpisodes:
      return "New Episodes"
    case .watchlist:
      return "My Series"
    }
  }

  // `subscribed` query parameter: 0 — all unwatched serials with new episodes, 1 — watchlist only
  var subscribed: Int { rawValue }
}

@MainActor
class WatchingModel: ObservableObject {

  private var authState: AuthState
  private var errorHandler: ErrorHandler
  private var contentService: VideoContentService
  private var bag = Set<AnyCancellable>()

  @Published public var serials: [WatchingSerial] = []
  @Published public var isLoading: Bool = true
  @Published public var filter: WatchingFilter = .watchlist

  init(itemsService: VideoContentService, authState: AuthState, errorHandler: ErrorHandler) {
    self.contentService = itemsService
    self.authState = authState
    self.errorHandler = errorHandler
  }

  func fetchItems() async {
    guard authState.userState == .authorized else {
      subscribeForAuth()
      return
    }

    isLoading = true
    do {
      let data = try await contentService.fetchWatchingSerials(subscribed: filter.subscribed)
      serials = data.items
      isLoading = false
    } catch {
      Logger.app.debug("fetch watching serials error: \(error)")
      isLoading = false
      errorHandler.setError(error)
    }
  }

  func select(filter: WatchingFilter) {
    guard filter != self.filter else { return }
    self.filter = filter
    serials = []
    Task {
      await fetchItems()
    }
  }

  @Sendable @MainActor
  func refresh() async {
    errorHandler.reset()
    Logger.app.debug("refetch watching serials")
    await fetchItems()
  }

  private func subscribeForAuth() {
    authState.$userState.filter({ $0 == .authorized }).first().sink { [weak self] _ in
      Task {
        await self?.refresh()
      }
    }.store(in: &bag)
  }

}
