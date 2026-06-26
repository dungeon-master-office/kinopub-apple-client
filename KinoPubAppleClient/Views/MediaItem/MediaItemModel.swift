//
//  MediaItemModel.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 2.08.2023.
//

import Foundation
import KinoPubBackend
import OSLog
import KinoPubLogging
import KinoPubKit

@MainActor
class MediaItemModel: ObservableObject {

  private var itemsService: VideoContentService
  private var actionsService: UserActionsService
  private var downloadManager: DownloadManager<DownloadMeta>
  private var errorHandler: ErrorHandler
  public var linkProvider: NavigationLinkProvider
  public var mediaItemId: Int

  @Published public var mediaItem: MediaItem = MediaItem.mock()
  @Published public var itemLoaded: Bool = false
  @Published public var bookmarkFolders: [Bookmark] = []
  @Published public var relatedItems: [MediaItem] = []
  /// Resolved cast/crew portrait URLs (by name) from TMDB.
  @Published public var personImages: [String: URL] = [:]

  private let tmdbService: TMDBService = AppContext.shared.tmdbService

  /// Actor names parsed from the comma-separated `cast` field (trimmed, non-empty).
  public var castNames: [String] {
    mediaItem.cast
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  /// Director names parsed from the comma-separated `director` field.
  public var directorNames: [String] {
    mediaItem.director
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  /// Resolve TMDB portraits for the visible cast & crew (best-effort, cached).
  func loadCastPhotos() async {
    let names = Array(Set(castNames.prefix(12)).union(directorNames))
    await withTaskGroup(of: (String, URL?).self) { group in
      for name in names where personImages[name] == nil {
        group.addTask { [tmdbService] in (name, await tmdbService.personImageURL(for: name)) }
      }
      for await (name, url) in group {
        if let url { personImages[name] = url }
      }
    }
  }

  /// The content type to use for facet filters opened from this item, so a
  /// serial's genre opens serials and a movie's opens movies.
  private var facetContentType: MediaType {
    MediaType(rawValue: mediaItem.type) ?? .movie
  }

  private func facetFilter(genres: [Int] = [], countries: [Int] = [], year: String? = nil) -> MediaItemsFilter {
    MediaItemsFilter(contentType: facetContentType,
                     genres: genres,
                     countries: countries,
                     year: year,
                     age: nil,
                     sort: nil)
  }

  // MARK: - Tappable metadata routes

  /// Route to a catalog filtered by a single genre.
  func genreRoute(id: Int, title: String) -> (any Hashable)? {
    linkProvider.filteredCatalog(filter: facetFilter(genres: [id]), title: title)
  }

  /// Route to a catalog filtered by a single country.
  func countryRoute(id: Int, title: String) -> (any Hashable)? {
    linkProvider.filteredCatalog(filter: facetFilter(countries: [id]), title: title)
  }

  /// Route to a catalog filtered by a single year.
  func yearRoute(_ year: Int) -> (any Hashable)? {
    linkProvider.filteredCatalog(filter: facetFilter(year: "\(year)"), title: "\(year)")
  }

  /// Route to a person search for an actor (kino.pub `field=cast`).
  func actorRoute(_ name: String) -> (any Hashable)? {
    linkProvider.personSearch(query: name, field: "cast", title: name)
  }

  /// Route to a person search for a director (kino.pub `field=director`).
  func directorRoute(_ name: String) -> (any Hashable)? {
    linkProvider.personSearch(query: name, field: "director", title: name)
  }

  init(mediaItemId: Int,
       itemsService: VideoContentService,
       downloadManager: DownloadManager<DownloadMeta>,
       linkProvider: NavigationLinkProvider,
       errorHandler: ErrorHandler,
       actionsService: UserActionsService = AppContext.shared.actionsService) {
    self.itemsService = itemsService
    self.mediaItemId = mediaItemId
    self.linkProvider = linkProvider
    self.errorHandler = errorHandler
    self.downloadManager = downloadManager
    self.actionsService = actionsService
  }

  func fetchData() {
    Task {
      do {
        mediaItem = try await itemsService.fetchDetails(for: "\(mediaItemId)").item
        let mediaId = mediaItem.id
        mediaItem.seasons = mediaItem.seasons?.map({ $0.mediaId = mediaId; return $0 })
        itemLoaded = true
        fetchRelated()
      } catch {
        errorHandler.setError(error)
      }
    }
  }

  /// Loads items similar to the current one (same primary genre & content type)
  /// using the catalog filter endpoint. Errors are surfaced but never fatal.
  func fetchRelated() {
    Task {
      do {
        let contentType = MediaType(rawValue: mediaItem.type) ?? .movie
        var genres: [Int] = []
        if let genreId = mediaItem.genres.first?.id {
          genres.append(genreId)
        }
        let filter = MediaItemsFilter(contentType: contentType,
                                      genres: genres,
                                      countries: [],
                                      year: nil,
                                      age: nil,
                                      sort: nil)
        let response = try await itemsService.filter(filter: filter, page: nil)
        relatedItems = response.items
          .filter { $0.id != mediaItem.id }
          .prefix(15)
          .map { $0 }
      } catch {
        errorHandler.setError(error)
      }
    }
  }
  
  func startDownload(item: DownloadableMediaItem, file: FileInfo) {
    _ = downloadManager.startDownload(url: URL(string: file.url.http)!, withMetadata: DownloadMeta.make(from: item))
  }

  func toggleWatched() {
    Task {
      do {
        try await actionsService.toggleWatching(id: mediaItemId, video: nil, season: nil)
        fetchData()
      } catch {
        errorHandler.setError(error)
      }
    }
  }

  func toggleEpisodeWatched(episodeNumber: Int, season: Int) {
    Task {
      do {
        try await actionsService.toggleWatching(id: mediaItemId, video: episodeNumber, season: season)
        fetchData()
      } catch {
        errorHandler.setError(error)
      }
    }
  }

  func toggleWatchlist() {
    Task {
      do {
        try await actionsService.toggleWatchlist(id: mediaItemId)
        fetchData()
      } catch {
        errorHandler.setError(error)
      }
    }
  }

  func loadBookmarkFolders() {
    Task {
      do {
        bookmarkFolders = try await actionsService.fetchBookmarks()
      } catch {
        errorHandler.setError(error)
      }
    }
  }

  func toggleBookmark(folderId: Int) {
    Task {
      do {
        try await actionsService.toggleBookmark(itemId: mediaItemId, folderId: folderId)
      } catch {
        errorHandler.setError(error)
      }
    }
  }

}
