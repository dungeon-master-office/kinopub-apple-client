//
//  CollectionsService.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 24.06.2026.
//

import Foundation
import KinoPubBackend

protocol CollectionsService {
  func fetchCollections(page: Int?) async throws -> [Collection]
  func fetchCollection(id: Int) async throws -> (Collection, [MediaItem])
}

protocol CollectionsServiceProvider {
  var collectionsService: CollectionsService { get set }
}

struct CollectionsServiceMock: CollectionsService {

  func fetchCollections(page: Int?) async throws -> [Collection] {
    return []
  }

  func fetchCollection(id: Int) async throws -> (Collection, [MediaItem]) {
    return (Collection.mock(id: id), [])
  }

}
