//
//  VideoContentServiceImpl.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 26.07.2023.
//

import Foundation
import KinoPubBackend

final class VideoContentServiceImpl: VideoContentService {

  private var apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  func fetch(shortcut: MediaShortcut, contentType: MediaType, page: Int?) async throws -> PaginatedData<MediaItem> {
    let request = ShortcutItemsRequest(shortcut: shortcut, contentType: contentType, page: page)
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: PaginatedData<MediaItem>.self)
    return response
  }

  func search(query: String?, page: Int?) async throws -> PaginatedData<MediaItem> {
    let request = SearchItemsRequest(contentType: nil, page: page, query: query)
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: PaginatedData<MediaItem>.self)
    return response
  }

  func filter(filter: MediaItemsFilter, page: Int?) async throws -> PaginatedData<MediaItem> {
    let request = FilterItemsRequest(contentType: filter.contentType,
                                     genres: filter.genres,
                                     countries: filter.countries,
                                     year: filter.year,
                                     sort: filter.sort,
                                     page: page)
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: PaginatedData<MediaItem>.self)
    return response
  }

  func fetchGenres() async throws -> [MediaGenre] {
    let request = GenresRequest()
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: ArrayData<MediaGenre>.self)
    return response.items
  }

  func fetchDetails(for id: String) async throws -> SingleItemData<MediaItem> {
    let request = ItemDetailsRequest(id: id)
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: SingleItemData<MediaItem>.self)
    return response
  }
  
  func fetchBookmarks() async throws -> ArrayData<Bookmark> {
    let request = BookmarksRequest()
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: ArrayData<Bookmark>.self)
    return response
  }
  
  func fetchBookmarkItems(id: String) async throws -> ArrayData<MediaItem> {
    let request = BookmarkItemsRequest(id: id)
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: ArrayData<MediaItem>.self)
    return response
  }

  func fetchHistory(page: Int?) async throws -> HistoryData {
    let request = HistoryRequest(page: page)
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: HistoryData.self)
    return response
  }

  func fetchWatchingSerials(subscribed: Int?) async throws -> ArrayData<WatchingSerial> {
    let request = WatchingSerialsRequest(subscribed: subscribed)
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: ArrayData<WatchingSerial>.self)
    return response
  }

}
