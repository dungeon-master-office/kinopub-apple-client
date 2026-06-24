//
//  SeasonModel.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 4.11.2023.
//

import Foundation
import KinoPubBackend
import KinoPubKit
import OSLog
import KinoPubLogging

class SeasonModel: ObservableObject {

  public var season: Season
  public var linkProvider: NavigationLinkProvider
  private var downloadManager: DownloadManager<DownloadMeta>

  init(season: Season,
       linkProvider: NavigationLinkProvider,
       downloadManager: DownloadManager<DownloadMeta> = AppContext.shared.downloadManager) {
    self.season = season
    self.linkProvider = linkProvider
    self.downloadManager = downloadManager
  }

  func filledEpisode(_ episode: Episode) -> Episode {
    let episode = episode
    episode.seasonNumber = season.number
    episode.mediaId = season.mediaId
    return episode
  }

  /// Builds a `DownloadMeta` for a single episode. Mirrors the shape used by
  /// `MediaItem.downloadableItems` (name "S{season}E{episode}", per-episode files & watching metadata)
  /// but only depends on data that is available from a `Season`/`Episode`.
  func downloadMeta(for episode: Episode) -> DownloadMeta {
    let name = "S\(season.number)E\(episode.number)"
    return DownloadMeta(id: episode.id,
                        files: episode.files,
                        originalTitle: name,
                        localizedTitle: episode.fixedTitle,
                        imageUrl: episode.thumbnail,
                        metadata: WatchingMetadata(id: season.mediaId ?? episode.id,
                                                   video: episode.number,
                                                   season: season.number))
  }

  func startDownload(episode: Episode, file: FileInfo) {
    guard let url = URL(string: file.url.http) else {
      Logger.app.error("[DOWNLOAD] Invalid download url for episode \(episode.id)")
      return
    }
    _ = downloadManager.startDownload(url: url, withMetadata: downloadMeta(for: episode))
  }
}
