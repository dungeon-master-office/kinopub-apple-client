//
//  CollectionsService.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 24.06.2026.
//

import Foundation
import KinoPubBackend

protocol CollectionsService {
  func fetchCollections(page: Int?, sort: String?) async throws -> CollectionsData
  func fetchCollection(id: Int) async throws -> (Collection, [MediaItem])
}

protocol CollectionsServiceProvider {
  var collectionsService: CollectionsService { get set }
}

struct CollectionsServiceMock: CollectionsService {

  func fetchCollections(page: Int?, sort: String?) async throws -> CollectionsData {
    return .mock(data: [])
  }

  func fetchCollection(id: Int) async throws -> (Collection, [MediaItem]) {
    return (Collection.mock(id: id), [])
  }

}
