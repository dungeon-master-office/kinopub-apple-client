//
//  VideoContentService.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 26.07.2023.
//

import Foundation
import KinoPubBackend

protocol VideoContentService {
  func fetch(shortcut: MediaShortcut, contentType: MediaType, page: Int?, forceRefresh: Bool) async throws -> PaginatedData<MediaItem>
  func search(query: String?, contentType: MediaType?, field: String?, page: Int?) async throws -> PaginatedData<MediaItem>
  func filter(filter: MediaItemsFilter, page: Int?, forceRefresh: Bool) async throws -> PaginatedData<MediaItem>
  /// Films of a person via the `/v1/items?cast=`/`director=` FILTER (reliable, unlike the
  /// `search?field=cast` full-text match). `field` is "cast" or "director"; no type restriction so
  /// the full filmography (movies + series) is returned.
  func itemsByPerson(name: String, field: String, page: Int?) async throws -> PaginatedData<MediaItem>
  func fetchGenres(type: MediaType?) async throws -> [MediaGenre]
  func fetchCountries() async throws -> [Country]
  func fetchDetails(for id: String) async throws -> SingleItemData<MediaItem>
  func fetchBookmarks() async throws -> ArrayData<Bookmark>
  func fetchBookmarkItems(id: String) async throws -> ArrayData<MediaItem>
  func fetchHistory(page: Int?) async throws -> HistoryData
  func fetchWatchingSerials(subscribed: Int?, type: String?) async throws -> ArrayData<WatchingSerial>
  func fetchWatchingMovies() async throws -> ArrayData<WatchingSerial>
  func fetchTVChannels() async throws -> [TVChannel]
  func fetchComments(for id: Int) async throws -> CommentsData
}

protocol VideoContentServiceProvider {
  var contentService: VideoContentService { get set }
}

extension VideoContentService {
  // Convenience overloads so call sites that don't care about cache freshness stay unchanged.
  func fetch(shortcut: MediaShortcut, contentType: MediaType, page: Int?) async throws -> PaginatedData<MediaItem> {
    try await fetch(shortcut: shortcut, contentType: contentType, page: page, forceRefresh: false)
  }

  func filter(filter: MediaItemsFilter, page: Int?) async throws -> PaginatedData<MediaItem> {
    try await self.filter(filter: filter, page: page, forceRefresh: false)
  }
}

struct VideoContentServiceMock: VideoContentService {

  func fetch(shortcut: MediaShortcut, contentType: MediaType, page: Int?, forceRefresh: Bool) async throws -> PaginatedData<MediaItem> {
    return PaginatedData.mock(data: [])
  }

  func search(query: String?, contentType: MediaType?, field: String?, page: Int?) async throws -> PaginatedData<MediaItem> {
    return PaginatedData.mock(data: [])
  }

  func filter(filter: MediaItemsFilter, page: Int?, forceRefresh: Bool) async throws -> PaginatedData<MediaItem> {
    return PaginatedData.mock(data: [])
  }

  func itemsByPerson(name: String, field: String, page: Int?) async throws -> PaginatedData<MediaItem> {
    return PaginatedData.mock(data: [])
  }

  func fetchGenres(type: MediaType?) async throws -> [MediaGenre] {
    return []
  }

  func fetchCountries() async throws -> [Country] {
    return []
  }

  func fetchDetails(for id: String) async throws -> SingleItemData<MediaItem> {
    return SingleItemData.mock(data: MediaItem.mock())
  }
  
  func fetchBookmarks() async throws -> ArrayData<Bookmark> {
    return ArrayData.mock(data: [])
  }
  
  func fetchBookmarkItems(id: String) async throws -> ArrayData<MediaItem> {
    return ArrayData.mock(data: [])
  }

  func fetchHistory(page: Int?) async throws -> HistoryData {
    return HistoryData.mock(data: [])
  }

  func fetchWatchingSerials(subscribed: Int?, type: String?) async throws -> ArrayData<WatchingSerial> {
    return ArrayData.mock(data: [])
  }

  func fetchWatchingMovies() async throws -> ArrayData<WatchingSerial> {
    return ArrayData.mock(data: [])
  }

  func fetchTVChannels() async throws -> [TVChannel] {
    return []
  }

  func fetchComments(for id: Int) async throws -> CommentsData {
    return CommentsData.mock()
  }

}
