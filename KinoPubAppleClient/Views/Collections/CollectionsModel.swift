//
//  CollectionsModel.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 24.06.2026.
//

import Foundation
import KinoPubBackend
import OSLog
import KinoPubLogging
import Combine

/// Sort tabs shown on the Collections screen, mirroring the web /selection sections.
enum CollectionsSort: CaseIterable, Identifiable {
  case new
  case popular
  case views

  var id: Self { self }

  /// Localized pill title.
  var title: String {
    switch self {
    case .new: return "New".localized
    case .popular: return "Popular".localized
    case .views: return "Views".localized
    }
  }

  /// API `sort` parameter value.
  var apiValue: String {
    switch self {
    case .new: return "created-"
    case .popular: return "watchers-"
    case .views: return "views-"
    }
  }
}

@MainActor
class CollectionsModel: ObservableObject {

  private var authState: AuthState
  private var errorHandler: ErrorHandler
  private var collectionsService: CollectionsService
  private var bag = Set<AnyCancellable>()

  @Published public var collections: [Collection] = []
  @Published public var isLoading: Bool = true
  @Published public var selectedSort: CollectionsSort = .new

  private var pagination: Pagination?
  private var isLoadingMore: Bool = false

  init(collectionsService: CollectionsService, authState: AuthState, errorHandler: ErrorHandler) {
    self.collectionsService = collectionsService
    self.authState = authState
    self.errorHandler = errorHandler
    subscribe()
  }

  func fetchCollections() async {
    guard authState.userState == .authorized else {
      subscribeForAuth()
      return
    }

    isLoading = true
    pagination = nil
    do {
      let data = try await collectionsService.fetchCollections(page: nil, sort: selectedSort.apiValue)
      collections = data.collections
      pagination = data.pagination
    } catch {
      Logger.app.debug("fetch collections error: \(error)")
      errorHandler.setError(error)
    }
    isLoading = false
  }

  /// Loads the next page when the user scrolls near the end of the grid.
  func loadMoreContent(after collection: Collection) {
    guard let pagination = pagination, !isLoadingMore else {
      return
    }
    guard pagination.current < pagination.total else {
      return
    }

    let thresholdIndex = collections.index(collections.endIndex, offsetBy: -1)
    guard thresholdIndex == collections.firstIndex(of: collection) else {
      return
    }

    Logger.app.debug("load more collections after: \(collection.id)")
    Task { await fetchNextPage() }
  }

  private func fetchNextPage() async {
    guard let pagination = pagination, !isLoadingMore else { return }
    isLoadingMore = true
    defer { isLoadingMore = false }

    let nextPage = pagination.current + 1
    do {
      let data = try await collectionsService.fetchCollections(page: nextPage, sort: selectedSort.apiValue)
      collections.append(contentsOf: data.collections)
      self.pagination = data.pagination
    } catch {
      Logger.app.debug("fetch more collections error: \(error)")
      errorHandler.setError(error)
    }
  }

  @Sendable @MainActor
  func refresh() async {
    errorHandler.reset()
    await fetchCollections()
  }

  private func subscribe() {
    $selectedSort
      .dropFirst()
      .removeDuplicates()
      .sink { [weak self] _ in
        Task { await self?.refresh() }
      }.store(in: &bag)
  }

  private func subscribeForAuth() {
    authState.$userState.filter({ $0 == .authorized }).first().sink { [weak self] _ in
      Task {
        await self?.refresh()
      }
    }.store(in: &bag)
  }

}
