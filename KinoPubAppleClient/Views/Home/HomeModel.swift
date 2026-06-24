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

  private var authState: AuthState
  private var errorHandler: ErrorHandler
  private var itemsService: VideoContentService
  private var bag = Set<AnyCancellable>()

  @Published public var shelves: [Shelf] = HomeModel.skeletonShelves()
  @Published public var featured: [MediaItem] = []
  @Published public var continueWatching: [MediaItem] = []

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
    continueWatching = Array(((try? await history)?.history.map { $0.item } ?? []).prefix(15))
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
