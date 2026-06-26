//
//  Episode.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation

public class Episode: Codable, Hashable, Identifiable {
  
  public let id: Int
  public let title: String
  public let thumbnail: String
  public let duration: Int
  public let tracks: Int
  public let number: Int
  public let ac3: Int
  public let audios: [EpisodeAudio]
  public let watched: Int
  public let watching: EpisodeWatching
  public let subtitles: [Subtitle]
  public let files: [FileInfo]
  public var seasonNumber: Int?
  public var mediaId: Int?
  /// Parent series title, set when navigating to the player so it can be shown there.
  public var mediaTitle: String?

  public var fixedTitle: String {
    if title.isEmpty {
      return "Серия \(number)"
    }
    return title
  }
  
  public init(id: Int, title: String, thumbnail: String, duration: Int, tracks: Int, number: Int, ac3: Int, audios: [EpisodeAudio], watched: Int, watching: EpisodeWatching, subtitles: [Subtitle], files: [FileInfo]) {
    self.id = id
    self.title = title
    self.thumbnail = thumbnail
    self.duration = duration
    self.tracks = tracks
    self.number = number
    self.ac3 = ac3
    self.audios = audios
    self.watched = watched
    self.watching = watching
    self.subtitles = subtitles
    self.files = files
  }
  
  public static func == (lhs: Episode, rhs: Episode) -> Bool {
    lhs.id == rhs.id
  }
  
  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

public extension Episode {
  /// "Finished": remaining time is within a small threshold (~8% of length, clamped 60...180s),
  /// so Continue should offer the next episode rather than this one's tail.
  var isWatchedToEnd: Bool {
    guard duration > 0, watching.time > 0 else { return false }
    let threshold = min(max(Int(Double(duration) * 0.08), 60), 180)
    return watching.time >= duration - threshold
  }
}

extension Episode: PlayableItem {
  public var trailer: Trailer? { nil }
  public var metadata: WatchingMetadata {
    WatchingMetadata(id: mediaId ?? id, video: number, season: seasonNumber)
  }

  public var playerTitle: String { mediaTitle ?? fixedTitle }

  public var playerSubtitle: String? {
    var parts: [String] = []
    if let season = seasonNumber { parts.append("S\(season)") }
    parts.append("E\(number)")
    var subtitle = parts.joined(separator: " · ")
    if mediaTitle != nil, !title.isEmpty {
      subtitle += " · \(title)"
    }
    return subtitle
  }
}
