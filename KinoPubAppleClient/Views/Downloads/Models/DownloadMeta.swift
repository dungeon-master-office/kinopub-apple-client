//
//  DownloadMeta.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 10.11.2023.
//

import Foundation
import KinoPubBackend

public struct DownloadMeta: PlayableItem, Codable, Equatable {
  public var id: Int
  public var files: [FileInfo]
  public var trailer: Trailer? { nil }
  public var originalTitle: String
  public var localizedTitle: String
  public var imageUrl: String
  public var metadata: WatchingMetadata
  /// The quality the user chose to download (e.g. "1080p"). Optional so older saved entries decode.
  public var quality: String?
  /// The episode marker for series (e.g. "S4E4"); nil for movies. Kept separate from the titles so
  /// it isn't repeated on both the localized and original title lines.
  public var episode: String?
}

extension DownloadMeta {
  static func make(from item: DownloadableMediaItem, quality: String? = nil) -> DownloadMeta {
    return DownloadMeta(id: item.mediaItem.id,
                        files: item.files,
                        originalTitle: item.mediaItem.originalTitle,
                        localizedTitle: item.mediaItem.localizedTitle,
                        imageUrl: item.mediaItem.posters.small,
                        metadata: item.watchingMetadata,
                        quality: quality,
                        episode: item.mediaItem.isSeries ? item.name : nil)
  }
}
