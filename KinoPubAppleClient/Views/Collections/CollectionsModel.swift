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

@MainActor
class CollectionsModel: ObservableObject {

  private var authState: AuthState
  private var errorHandler: ErrorHandler
  private var collectionsService: CollectionsService
  private var bag = Set<AnyCancellable>()

  @Published public var collections: [Collection] = []
  @Published public var isLoading: Bool = true

  init(collectionsService: CollectionsService, authState: AuthState, errorHandler: ErrorHandler) {
    self.collectionsService = collectionsService
    self.authState = authState
    self.errorHandler = errorHandler
  }

  func fetchCollections() async {
    guard authState.userState == .authorized else {
      subscribeForAuth()
      return
    }

    isLoading = true
    do {
      collections = try await collectionsService.fetchCollections(page: nil)
    } catch {
      Logger.app.debug("fetch collections error: \(error)")
      errorHandler.setError(error)
    }
    isLoading = false
  }

  @Sendable @MainActor
  func refresh() async {
    errorHandler.reset()
    await fetchCollections()
  }

  private func subscribeForAuth() {
    authState.$userState.filter({ $0 == .authorized }).first().sink { [weak self] _ in
      Task {
        await self?.refresh()
      }
    }.store(in: &bag)
  }

}
