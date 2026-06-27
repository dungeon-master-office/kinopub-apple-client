//
//  FilterItemsRequest.swift
//
//
//  Created by Kirill Kunst on 4.08.2023.
//

import Foundation

public struct FilterItemsRequest: Endpoint {

  private var contentType: MediaType?
  /// Overrides `type` with a raw value (e.g. comma-separated "movie,serial" for the Anime preset).
  private var rawType: String?
  private var genres: [Int]?
  private var countries: [Int]?
  private var year: String?
  private var age: String?
  private var sort: String?
  /// Filter by director / cast name — `/v1/items?director=`/`cast=` (verified to actually filter live).
  private var director: String?
  private var cast: String?
  private var subtitles: String?
  private var imdb: String?
  private var kinopoisk: String?
  private var quality: [String]?
  private var conditions: [String]?
  private var period: String?
  private var language: String?
  private var translation: String?
  private var page: Int?

  public init(contentType: MediaType? = nil,
              rawType: String? = nil,
              genres: [Int]? = nil,
              countries: [Int]? = nil,
              year: String? = nil,
              age: String? = nil,
              sort: String? = nil,
              director: String? = nil,
              cast: String? = nil,
              subtitles: String? = nil,
              imdb: String? = nil,
              kinopoisk: String? = nil,
              quality: [String]? = nil,
              conditions: [String]? = nil,
              period: String? = nil,
              language: String? = nil,
              translation: String? = nil,
              page: Int? = nil) {
    self.contentType = contentType
    self.rawType = rawType
    self.genres = genres
    self.countries = countries
    self.year = year
    self.age = age
    self.sort = sort
    self.director = director
    self.cast = cast
    self.subtitles = subtitles
    self.imdb = imdb
    self.kinopoisk = kinopoisk
    self.quality = quality
    self.conditions = conditions
    self.period = period
    self.language = language
    self.translation = translation
    self.page = page
  }

  public var path: String {
    "/v1/items"
  }

  public var method: String {
    "GET"
  }

  public var parameters: [String: Any]? {
    var params = [String: Any]()

    if let rawType = rawType, !rawType.isEmpty {
      params["type"] = rawType
    } else if let contentType = contentType {
      params["type"] = contentType.rawValue
    }

    if let genres = genres, !genres.isEmpty {
      params["genre"] = genres.map { "\($0)" }.joined(separator: ",")
    }

    if let director = director, !director.isEmpty {
      params["director"] = director
    }

    if let cast = cast, !cast.isEmpty {
      params["cast"] = cast
    }

    if let countries = countries, !countries.isEmpty {
      params["country"] = countries.map { "\($0)" }.joined(separator: ",")
    }

    if let year = year, !year.isEmpty {
      params["year"] = year
    }

    if let sort = sort, !sort.isEmpty {
      params["sort"] = sort
    }

    // Period (e.g. popular-this-month) maps to the web's `period` param. Sent server-side rather than
    // approximated client-side by `created_at` — that approximation is wrong for a views/watchers
    // ranking (it means "added recently", which would empty a popularity-sorted list).
    if let period = period, !period.isEmpty {
      params["period"] = period
    }

    // The remaining web facets (rating / subtitles / language / translation / age / HD / 4K / AC3)
    // are silently ignored by /v1/items, so the ones we can reproduce are applied client-side on the
    // results — see `MediaItemsFilter.clientSideMatches`.

    if let page = page {
      params["page"] = "\(page)"
    }

    return params
  }

  public var headers: [String: String]? {
    nil
  }

  public var forceSendAsGetParams: Bool { false }
}

extension FilterItemsRequest: CacheableRequest {
  // Cache only the first page briefly (catalogs + Home shelves) so revisiting a list is flicker-free.
  // Later pages are transient; pull-to-refresh / filter changes bypass via `forceRefresh`.
  public var cachePolicy: CachePolicy {
    (page == nil || page == 1) ? .memory(ttl: 120) : .noCache
  }
}
