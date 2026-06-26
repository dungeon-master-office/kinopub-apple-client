//
//  CollectionDetailModel.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 24.06.2026.
//

import Foundation
import KinoPubBackend
import OSLog
import KinoPubLogging

@MainActor
class CollectionDetailModel: ObservableObject {

  private var errorHandler: ErrorHandler
  private var collectionsService: CollectionsService

  public let collection: Collection

  @Published public var items: [MediaItem] = []
  @Published public var isLoading: Bool = true

  init(collection: Collection, collectionsService: CollectionsService, errorHandler: ErrorHandler) {
    self.collection = collection
    self.collectionsService = collectionsService
    self.errorHandler = errorHandler
  }

  func fetchItems() async {
    isLoading = true
    do {
      let result = try await collectionsService.fetchCollection(id: collection.id)
      items = result.1
    } catch {
      Logger.app.debug("fetch collection items error: \(error)")
      errorHandler.setError(error)
    }
    isLoading = false
  }

  @Sendable @MainActor
  func refresh() async {
    errorHandler.reset()
    await fetchItems()
  }

}
