//
//  BookmarksCatalog.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 28.07.2023.
//

import Foundation
import KinoPubBackend
import OSLog
import KinoPubLogging
import Combine

@MainActor
class BookmarksCatalog: ObservableObject {

  private var authState: AuthState
  private var contentService: VideoContentService
  private var errorHandler: ErrorHandler
  private var bag = Set<AnyCancellable>()

  @Published public var items: [Bookmark] = Bookmark.skeletonMock()
  /// Items per bookmark folder (by folder id), powering the Home-style shelves.
  @Published public var folderItems: [Int: [MediaItem]] = [:]

  init(itemsService: VideoContentService, authState: AuthState, errorHandler: ErrorHandler) {
    self.contentService = itemsService
    self.authState = authState
    self.errorHandler = errorHandler
    observeFolderCache()
    // Load on creation, not via the view's `.task` (unreliable in a compact split view / nested stack).
    Task { await fetchItems() }
  }

  /// Keep the folder list in sync with the shared cache so a folder deleted on its detail screen
  /// disappears here too (without a manual refresh).
  private func observeFolderCache() {
    AppContext.shared.libraryState.$bookmarkFolders
      .dropFirst()
      .receive(on: RunLoop.main)
      .sink { [weak self] folders in
        guard let self else { return }
        self.items = folders
        let ids = Set(folders.map { $0.id })
        self.folderItems = self.folderItems.filter { ids.contains($0.key) }
      }
      .store(in: &bag)
  }

  func fetchItems() async {
    guard authState.userState == .authorized else {
      subscribeForAuth()
      return
    }

    // Folder list comes from the shared session cache (single source of truth across the app);
    // only each folder's contents are fetched here.
    await AppContext.shared.libraryState.loadBookmarkFoldersIfNeeded()
    let bookmarks = AppContext.shared.libraryState.bookmarkFolders
    items = bookmarks
    await loadFolderItems(bookmarks)
  }

  /// Loads each folder's contents concurrently so every shelf can show its posters.
  private func loadFolderItems(_ bookmarks: [Bookmark]) async {
    let service = contentService
    await withTaskGroup(of: (Int, [MediaItem]).self) { group in
      for bookmark in bookmarks {
        group.addTask {
          let items = (try? await service.fetchBookmarkItems(id: "\(bookmark.id)").items) ?? []
          return (bookmark.id, items)
        }
      }
      for await (id, items) in group {
        folderItems[id] = items
      }
    }
  }

  

  @Sendable @MainActor
  func refresh() async {
    items = Bookmark.skeletonMock()
    folderItems = [:]
    Logger.app.debug("refetch bookmarks")
    // Pull-to-refresh forces a fresh folder list (e.g. after creating/renaming a folder).
    await AppContext.shared.libraryState.reloadBookmarkFolders()
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
