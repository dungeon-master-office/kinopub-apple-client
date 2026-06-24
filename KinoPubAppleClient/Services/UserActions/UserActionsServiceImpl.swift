//
//  UserActionsServiceImpl.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 11.11.2023.
//

import Foundation
import KinoPubBackend

final class UserActionsServiceImpl: UserActionsService {
  
  private var apiClient: APIClient
  
  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }
  
  func markWatch(id: Int, time: Int, video: Int?, season: Int?) async throws {
    let request = MarkTimeRequest(id: id, time: time, video: video, season: season)
    _ = try await apiClient.performRequest(with: request, decodingType: EmptyResponseData.self)
  }
  
  func fetchWatchMark(id: Int, video: Int?, season: Int?) async throws -> WatchData {
    let request = GetWatchingDataRequest(id: id, video: video, season: season)
    return try await apiClient.performRequest(with: request, decodingType: WatchData.self)
  }
  
  func toggleWatching(id: Int, video: Int?, season: Int?) async throws {
    let request = ToggleWatchingRequest(id: id, video: video ?? 0, season: season)
    _ = try await apiClient.performRequest(with: request, decodingType: ToggleWatchingResponse.self)
  }

  func toggleWatchlist(id: Int) async throws {
    let request = ToggleWatchlistRequest(id: id)
    _ = try await apiClient.performRequest(with: request, decodingType: ToggleWatchingResponse.self)
  }

  func toggleBookmark(itemId: Int, folderId: Int) async throws {
    let request = ToggleBookmarkFolderRequest(item: itemId, folder: folderId)
    _ = try await apiClient.performRequest(with: request, decodingType: EmptyResponseData.self)
  }

  func fetchBookmarks() async throws -> [Bookmark] {
    let request = BookmarksRequest()
    return try await apiClient.performRequest(with: request, decodingType: ArrayData<Bookmark>.self).items
  }

}
