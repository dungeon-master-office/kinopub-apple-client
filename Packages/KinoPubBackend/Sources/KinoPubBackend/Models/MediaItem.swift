//
//  MediaItem.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation

public struct MediaItem: Codable, Hashable {
  public let id: Int
  public let type: String
  public let subtype: String
  public let title: String
  public let year: Int
  public let cast: String
  public let director: String
  public let genres: [TypeClass]
  public let countries: [Country]
  public let voice: String?
  public let duration: Duration
  public let langs: Int
  public let quality: Int
  public let plot: String
  public let imdb: Int?
  public let imdbRating: Double?
  public let imdbVotes: Int?
  public let kinopoisk: Int?
  public let kinopoiskRating: Double?
  public let kinopoiskVotes: Int?
  public let rating: Int
  public let ratingVotes: Int
  public let ratingPercentage: Double
  public let views: Int
  public let comments: Int
  public let posters: Posters
  public let trailer: Trailer?
  public let finished: Bool
  public let advert: Bool
  public let poorQuality: Bool
  public let createdAt: Int
  public let updatedAt: Int
  public let inWatchlist: Bool?
  public let subscribed: Bool?
  public let ac3: Int?
  public let bookmarks: [TypeClass]?
  public var seasons: [Season]?
  public let videos: [Video]?
  public let skeleton: Bool?

  private enum CodingKeys: String, CodingKey {
    case id = "id"
    case type = "type"
    case subtype = "subtype"
    case title = "title"
    case year = "year"
    case cast = "cast"
    case director = "director"
    case genres = "genres"
    case countries = "countries"
    case voice = "voice"
    case duration = "duration"
    case langs = "langs"
    case quality = "quality"
    case plot = "plot"
    case imdb = "imdb"
    case imdbRating = "imdb_rating"
    case imdbVotes = "imdb_votes"
    case kinopoisk = "kinopoisk"
    case kinopoiskRating = "kinopoisk_rating"
    case kinopoiskVotes = "kinopoisk_votes"
    case rating = "rating"
    case ratingVotes = "rating_votes"
    case ratingPercentage = "rating_percentage"
    case views = "views"
    case comments = "comments"
    case posters = "posters"
    case trailer = "trailer"
    case finished = "finished"
    case advert = "advert"
    case poorQuality = "poor_quality"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
    case inWatchlist = "in_watchlist"
    case subscribed = "subscribed"
    case bookmarks = "bookmarks"
    case ac3 = "ac3"
    case seasons = "seasons"
    case videos = "videos"
    case skeleton = "skeleton"
  }
}

public extension MediaItem {
  var isSeries: Bool {
    // Drive off the content type — reliable even in list contexts where `seasons` isn't loaded yet.
    // (The old `!(seasons?.isEmpty ?? false)` returned TRUE for movies, whose `seasons` is nil.)
    if let mediaType = MediaType(rawValue: type) {
      switch mediaType {
      case .serial, .docuserial, .tvshow:
        return true
      case .movie, .documovie, .concert, .threeD:
        return false
      }
    }
    // Unknown type: fall back to whether real seasons are present.
    return !(seasons?.isEmpty ?? true)
  }

  /// Ordered (season, episode) pairs across all seasons.
  var orderedEpisodes: [(season: Season, episode: Episode)] {
    (seasons ?? [])
      .sorted { $0.number < $1.number }
      .flatMap { season in season.episodes.sorted { $0.number < $1.number }.map { (season, $0) } }
  }

  /// Shared "Continue" target for a series, used by both Home and the detail page so the
  /// behaviour is identical: the in-progress episode, or the episode after the last finished
  /// one. Returns nil for movies or when there's nothing to continue / everything is watched.
  func continueEpisode() -> (season: Season, episode: Episode)? {
    let ordered = orderedEpisodes
    guard let index = ordered.lastIndex(where: { $0.episode.watching.time > 0 || $0.episode.watched > 0 }) else {
      return nil
    }
    let entry = ordered[index]
    if entry.episode.watched > 0 || entry.episode.isWatchedToEnd {
      let next = index + 1
      return next < ordered.count ? ordered[next] : nil
    }
    return entry
  }
}

// MARK: - All series files list

public extension MediaItem {
  
  var downloadableItems: [DownloadableMediaItem] {
    return seasons?.flatMap({ season in
      season.episodes.map({ episode in
        DownloadableMediaItem(name: "S\(season.number)E\(episode.number)",
                              files: episode.files,
                              mediaItem: self,
                              watchingMetadata: WatchingMetadata(id: episode.id, video: episode.number, season: season.number))
      })
    }) ?? []
  }
  
}

// MARK: - Downloadable url

public extension MediaItem {

  var downloadableURL: URL {
    URL(string: videos?.last?.files.first?.url.http ?? "")!
  }
  
  var watchableURL: URL {
    URL(string: videos?.first?.files.first?.url.hls4 ?? "")!
  }
  
}

public extension MediaItem {
  static func skeletonMock() -> [MediaItem] {
    (0..<15).map { id in
      mock(id: id, skeleton: true)
    }
  }

  static func mock(id: Int = 1, skeleton: Bool = false) -> MediaItem {
    MediaItem(id: id, type: "test",
              subtype: "test",
              title: "Стражи Галактики. Часть 3 / Guardians of the Galaxy Vol. 3",
              year: 2023,
              cast: "Крис Пратт, Зои Салдана, Дэйв Батиста, Карен Гиллан, Пом Клементьефф, Вин Дизель, Брэдли Купер, Уилл Поултер, Шон Ганн, Чукуди Ивуджи, Линда Карделлини, Нэйтан Филлион, Сильвестр Сталлоне",
              director: "Джеймс Ганн",
              genres: [
                TypeClass(id: 1, title: "Comedy", shortTitle: nil),
                TypeClass(id: 2, title: "Action", shortTitle: nil),
                TypeClass(id: 3, title: "Fantastic", shortTitle: nil),
                TypeClass(id: 4, title: "Adventure", shortTitle: nil)
              ],
              countries: [
                Country(id: 1, title: "USA"),
                Country(id: 1, title: "France"),
                Country(id: 1, title: "Canada"),
                Country(id: 1, title: "New Zeland")
              ],
              voice: "Русский. Дубляж. Red Head Sound, Русский. Дубляж. Лицензия",
              duration: Duration(average: 0, total: 230),
              langs: 0,
              quality: 0,
              plot: "После финальных разборок с Таносом стражи успели прийти в себя, окрепнуть и даже разместить собственный штаб в далёкой-далёкой галактике. Стабильное настоящее, впрочем, не мешает Питеру Квиллу всё чаще возвращаться в прошлое, заливать разбитое гибелью Гаморы сердце дешёвым алкоголем и всячески страдать. Размеренные будни героев, число которых увеличилось за счёт помощника Йонду Краглина и советской собаки Космо, нарушает Адам Уорлок, наёмник некоего Верховного эволюционера. Много лет назад Эволюционер создал генетически модифицированного енота Ракету и сейчас намерен во что бы то ни стало вернуть своё творение обратно.",
              imdb: 0,
              imdbRating: 8.100,
              imdbVotes: 0,
              kinopoisk: 0,
              kinopoiskRating: 8.300,
              kinopoiskVotes: 0,
              rating: 0,
              ratingVotes: 0,
              ratingPercentage: 0,
              views: 730000,
              comments: 0,
              posters: Posters(small: "", medium: "", big: "", wide: ""),
              trailer: nil,
              finished: true,
              advert: true,
              poorQuality: false,
              createdAt: 0,
              updatedAt: 0,
              inWatchlist: false,
              subscribed: false,
              ac3: nil,
              bookmarks: nil,
              seasons: nil,
              videos: nil,
              skeleton: skeleton)
  }
}

extension MediaItem: Identifiable { }

public extension MediaItem {
  var originalTitle: String {
    title.split(separator: "/").last?.trimmingCharacters(in: .whitespaces) ?? title
  }

  var localizedTitle: String {
    title.split(separator: "/").first?.trimmingCharacters(in: .whitespaces) ?? title
  }
}

extension MediaItem: PlayableItem {
  public var files: [FileInfo] {
    videos?.first?.files ?? []
  }

  public var metadata: WatchingMetadata {
    WatchingMetadata(id: id, video: videos?.first?.number, season: nil)
  }

  public var playerTitle: String { localizedTitle }
}
