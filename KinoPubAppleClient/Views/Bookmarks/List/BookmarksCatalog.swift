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
  }

  func fetchItems() async {
    guard authState.userState == .authorized else {
      subscribeForAuth()
      return
    }

    do {
      let bookmarks = try await contentService.fetchBookmarks().items
      items = bookmarks
      await loadFolderItems(bookmarks)
    } catch {
      Logger.app.debug("fetch bookmarks error: \(error)")
      errorHandler.setError(error)
    }
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
