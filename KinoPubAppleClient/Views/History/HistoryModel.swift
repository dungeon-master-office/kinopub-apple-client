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
  @Published public var historyItems: [HistoryItem] = []
  @Published public var pagination: Pagination?
  @Published public var selectedType: MediaType?

  init(itemsService: VideoContentService, authState: AuthState, errorHandler: ErrorHandler) {
    self.contentService = itemsService
    self.authState = authState
    self.errorHandler = errorHandler
  }

  // MARK: - Derived state (filtering + day grouping)

  /// Whether the screen is still showing the initial skeleton placeholders.
  var isLoadingSkeleton: Bool {
    items.first(where: { $0.skeleton ?? false }) != nil
  }

  /// Media types present in the loaded history, in `MediaType.allCases` order. Used to build the filter pills.
  var availableTypes: [MediaType] {
    let present = Set(historyItems.compactMap { MediaType(rawValue: $0.item.type) })
    return MediaType.allCases.filter { present.contains($0) }
  }

  /// History items after applying the selected type filter, preserving recency order.
  private var filteredHistoryItems: [HistoryItem] {
    guard let selectedType else { return historyItems }
    return historyItems.filter { $0.item.type == selectedType.rawValue }
  }

  /// Filtered history grouped by calendar day, newest day first, recency preserved within a day.
  var groupedSections: [HistorySection] {
    let calendar = Calendar.current
    var order: [Date] = []
    var buckets: [Date: [HistoryItem]] = [:]

    for historyItem in filteredHistoryItems {
      let timestamp = historyItem.lastSeen ?? historyItem.time ?? 0
      let day = calendar.startOfDay(for: Date(timeIntervalSince1970: timestamp))
      if buckets[day] == nil {
        buckets[day] = []
        order.append(day)
      }
      buckets[day]?.append(historyItem)
    }

    return order
      .sorted(by: >)
      .map { day in
        HistorySection(day: day, items: buckets[day]?.map { $0.item } ?? [])
      }
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
    if isLoadingSkeleton {
      items = newItems
      historyItems = data.history
    } else {
      items.append(contentsOf: newItems)
      historyItems.append(contentsOf: data.history)
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
    historyItems = []
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

/// A single day's worth of history entries, used to render a grouped section.
struct HistorySection: Identifiable {
  let day: Date
  let items: [MediaItem]

  var id: Date { day }

  /// Localized header: "Today"/"Yesterday" when applicable, otherwise a medium localized date.
  var title: String {
    let calendar = Calendar.current
    if calendar.isDateInToday(day) {
      return "Today".localized
    }
    if calendar.isDateInYesterday(day) {
      return "Yesterday".localized
    }
    return HistorySection.dateFormatter.string(from: day)
  }

  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
  }()
}
