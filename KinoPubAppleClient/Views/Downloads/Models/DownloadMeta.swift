//
//  DownloadMeta.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 10.11.2023.
//

import Foundation
import KinoPubBackend
import KinoPubKit

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

extension DownloadMeta: DownloadFileNaming {
  /// Human-readable base filename for the saved file, e.g. "Бесстыжие S10E1 (480p)".
  public var downloadFileBaseName: String? {
    var name = localizedTitle
    if let episode, !episode.isEmpty { name += " \(episode)" }
    if let quality, !quality.isEmpty { name += " (\(quality))" }
    // Strip characters that are illegal / awkward in a filename.
    let cleaned = name
      .components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>"))
      .joined(separator: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return cleaned.isEmpty ? nil : cleaned
  }
}

extension DownloadMeta {
  /// Human-readable label for download notifications, e.g. "S1E3 · Title" or just "Title".
  var notificationTitle: String {
    [episode, localizedTitle]
      .compactMap { $0 }
      .filter { !$0.isEmpty }
      .joined(separator: " · ")
  }

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
