//
//  MediaCatalog.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 27.07.2023.
//

import Foundation
import KinoPubBackend
import OSLog
import KinoPubLogging
import Combine

@MainActor
class MediaCatalog: ObservableObject {

  private var authState: AuthState
  private var errorHandler: ErrorHandler
  private var itemsService: VideoContentService
  private var bag = Set<AnyCancellable>()

  @Published public var items: [MediaItem] = MediaItem.skeletonMock()
  @Published public var pagination: Pagination?
  @Published public var contentType: MediaType = .movie
  @Published public var shortcut: MediaShortcut = .hot
  /// Top-level sort control (moved out of the filter modal). Layers on top of any active filter.
  @Published public var sort: SortOption = .updated
  @Published public var query: String = ""
  @Published public var activeFilter: MediaItemsFilter?

  var title: String {
    contentType.title
  }

  /// Number of active filter facets (drives the toolbar filter badge).
  var activeFilterCount: Int {
    activeFilter?.activeCount ?? 0
  }

  /// Whether the sort differs from the section default (drives the sort dot).
  var isSortNonDefault: Bool {
    sort != .updated
  }

  init(itemsService: VideoContentService,
       authState: AuthState,
       errorHandler: ErrorHandler,
       contentType: MediaType = .movie,
       shortcut: MediaShortcut = .hot,
       filter: MediaItemsFilter? = nil) {
    self.itemsService = itemsService
    self.authState = authState
    self.errorHandler = errorHandler
    self.contentType = filter?.contentType ?? contentType
    self.shortcut = shortcut
    self.activeFilter = filter
    subscribe()
  }

  func fetchItems() async {
    await fetchItems(fillBurst: 0)
  }

  /// `fillBurst` bounds how many extra pages we auto-pull in one call to backfill the grid after a
  /// client-side facet trims a page (see below).
  private func fetchItems(fillBurst: Int) async {
    guard authState.userState == .authorized else {
      subscribeForAuth()
      return
    }

    do {
      let page = pagination != nil ? pagination!.current + 1 : nil
      if !query.isEmpty {
        let data = try await itemsService.search(query: query, contentType: nil, field: nil, page: page)
        handleData(items: data.items, pagination: data.pagination)
        return
      }
      // Sort is a top-level control now (was inside the filter modal): always go through the
      // filter endpoint with the chosen sort, layered on top of any active facet filter.
      var f = activeFilter ?? MediaItemsFilter(contentType: contentType, genres: [], countries: [], year: nil, age: nil, sort: nil)
      f.sort = (sort == .updated) ? nil : sort.rawValue
      let data = try await itemsService.filter(filter: f, page: page)
      // Apply the facets the mobile API ignores (rating/HD/4K/AC3/period) on the results, so the
      // in-app filter matches the website (see MediaItemsFilter.clientSideMatches).
      let now = Date().timeIntervalSince1970
      let incoming = f.hasClientSideFacets ? data.items.filter { f.clientSideMatches($0, now: now) } : data.items
      handleData(items: incoming, pagination: data.pagination)

      // A page can shrink to a few matches once facets are applied; pull more pages (bounded) so the
      // grid isn't left empty and load-more still has an anchor item to trigger the next fetch.
      if f.hasClientSideFacets, fillBurst < 6, loadedItemCount < 20,
         let p = pagination, p.current < p.total {
        await fetchItems(fillBurst: fillBurst + 1)
      }
    } catch {
      Logger.app.debug("fetch items error: \(error)")
      errorHandler.setError(error)
    }
  }

  private var loadedItemCount: Int {
    items.filter { !($0.skeleton ?? false) }.count
  }

  /// Initial appearance load. Once the catalog already holds a page, this returns immediately,
  /// so returning from a pushed detail neither refetches (losing scroll) nor appends a page.
  @MainActor
  func initialFetch() async {
    guard pagination == nil else { return }
    await fetchItems()
  }

  private func handleData(items incoming: [MediaItem], pagination newPagination: Pagination?) {
    if items.first(where: { $0.skeleton ?? false }) != nil {
      items = incoming
    } else {
      items.append(contentsOf: incoming)
    }
    pagination = newPagination
  }

  func loadMoreContent(after item: MediaItem) {
    guard let pagination = pagination else {
      return
    }

    let thresholdIndex = self.items.index(self.items.endIndex, offsetBy: -1)
    if thresholdIndex == self.items.firstIndex(of: item), pagination.current <= pagination.total {
      Logger.app.debug("load more content after item: \(item.id)")
      Task {
        await fetchItems()
      }
    }
  }

  @MainActor
  func refresh() {
    items = MediaItem.skeletonMock()
    pagination = nil
    errorHandler.reset()
    Task {
      Logger.app.debug("refetch items")
      await fetchItems()
    }
  }

  @MainActor
  func apply(filter: MediaItemsFilter) {
    contentType = filter.contentType
    activeFilter = filter
    refresh()
  }

  @MainActor
  func clearFilter() {
    guard activeFilter != nil else { return }
    activeFilter = nil
    refresh()
  }

  private func subscribe() {
    $contentType
      .dropFirst()
      .removeDuplicates()
      .sink { [weak self] _ in
      self?.refresh()
    }.store(in: &bag)

    $sort
      .dropFirst()
      .removeDuplicates()
      .sink { [weak self] _ in
      // Sort combines with the active filter (unlike the old shortcut, which cleared it).
      self?.refresh()
    }.store(in: &bag)

    $query
      .dropFirst()
      .removeDuplicates()
      .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
      .sink { [weak self] _ in
      self?.items = MediaItem.skeletonMock()
      self?.refresh()
    }.store(in: &bag)
  }

  private func subscribeForAuth() {
    authState.$userState.filter({ $0 == .authorized })
      .first()
      .removeDuplicates()
      .sink { [weak self] _ in
      self?.refresh()
    }.store(in: &bag)
  }

}
