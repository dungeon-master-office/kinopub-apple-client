//
//  HistoryModel.swift
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
class HistoryModel: ObservableObject {

  private var authState: AuthState
  private var errorHandler: ErrorHandler
  private var contentService: VideoContentService
  private var bag = Set<AnyCancellable>()

  @Published public var items: [MediaItem] = MediaItem.skeletonMock()
  @Published public var pagination: Pagination?

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

    do {
      let page = pagination != nil ? pagination!.current + 1 : nil
      let data = try await contentService.fetchHistory(page: page)
      handleData(data)
    } catch {
      Logger.app.debug("fetch history error: \(error)")
      errorHandler.setError(error)
    }
  }

  private func handleData(_ data: HistoryData) {
    let newItems = data.history.map { $0.item }
    if items.first(where: { $0.skeleton ?? false }) != nil {
      items = newItems
    } else {
      items.append(contentsOf: newItems)
    }
    pagination = data.pagination
  }

  func loadMoreContent(after item: MediaItem) {
    guard let pagination = pagination else {
      return
    }

    let thresholdIndex = self.items.index(self.items.endIndex, offsetBy: -1)
    if thresholdIndex == self.items.firstIndex(of: item), pagination.current <= pagination.total {
      Logger.app.debug("load more history after item: \(item.id)")
      Task {
        await fetchItems()
      }
    }
  }

  @Sendable @MainActor
  func refresh() async {
    items = MediaItem.skeletonMock()
    pagination = nil
    errorHandler.reset()
    Logger.app.debug("refetch history")
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
