//
//  CollectionsServiceImpl.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 24.06.2026.
//

import Foundation
import KinoPubBackend

final class CollectionsServiceImpl: CollectionsService {

  private var apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  func fetchCollections(page: Int?) async throws -> [Collection] {
    let request = CollectionsRequest(page: page)
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: CollectionsData.self)
    return response.collections
  }

  func fetchCollection(id: Int) async throws -> (Collection, [MediaItem]) {
    let request = CollectionViewRequest(id: id)
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: CollectionItemsData.self)
    let collection = response.collection ?? Collection.mock(id: id)
    return (collection, response.items)
  }

}
