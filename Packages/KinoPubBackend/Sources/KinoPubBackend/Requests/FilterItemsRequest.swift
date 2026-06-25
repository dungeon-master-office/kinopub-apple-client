//
//  FilterItemsRequest.swift
//
//
//  Created by Kirill Kunst on 4.08.2023.
//

import Foundation

public struct FilterItemsRequest: Endpoint {

  private var contentType: MediaType?
  private var genres: [Int]?
  private var countries: [Int]?
  private var year: String?
  private var age: String?
  private var sort: String?
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
              genres: [Int]? = nil,
              countries: [Int]? = nil,
              year: String? = nil,
              age: String? = nil,
              sort: String? = nil,
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
    self.genres = genres
    self.countries = countries
    self.year = year
    self.age = age
    self.sort = sort
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

    if let contentType = contentType {
      params["type"] = contentType.rawValue
    }

    if let genres = genres, !genres.isEmpty {
      params["genre"] = genres.map { "\($0)" }.joined(separator: ",")
    }

    if let countries = countries, !countries.isEmpty {
      params["country"] = countries.map { "\($0)" }.joined(separator: ",")
    }

    if let year = year, !year.isEmpty {
      params["year"] = year
    }

    if let age = age, !age.isEmpty {
      params["age"] = age
    }

    if let sort = sort, !sort.isEmpty {
      params["sort"] = sort
    }

    // NOTE: the parameters below are best-effort mappings to the kino.pub web
    // filter and may need adjustment. The official docs (kinoapi.com) document
    // `conditions` (array) and `quality` (array) but do not specify the exact
    // encoding for the subtitle / IMDb / Kinopoisk / HD / 4K / AC3 filters, so
    // these are inferred from the web client. They must NOT affect the
    // confidently-known genre/country/year/sort params above.
    if let subtitles = subtitles, !subtitles.isEmpty {
      params["subtitles"] = subtitles
    }

    if let imdb = imdb, !imdb.isEmpty {
      // Best-effort: minimum IMDb rating.
      params["imdb"] = imdb
    }

    if let kinopoisk = kinopoisk, !kinopoisk.isEmpty {
      // Best-effort: minimum Kinopoisk rating.
      params["kinopoisk"] = kinopoisk
    }

    if let quality = quality, !quality.isEmpty {
      // Best-effort: kino.pub expects `quality` as an array. The simple query
      // builder here can't emit `quality[]=`, so send a comma-joined list.
      params["quality"] = quality.joined(separator: ",")
    }

    if let conditions = conditions, !conditions.isEmpty {
      // Best-effort: HD/4K/AC3 "wants" map onto the `conditions` array; sent
      // comma-joined for the same reason as `quality` above.
      params["conditions"] = conditions.joined(separator: ",")
    }

    if let period = period, !period.isEmpty {
      // Best-effort: web "Period" dropdown.
      params["period"] = period
    }

    if let language = language, !language.isEmpty {
      // Best-effort: web "Язык" (audio language) dropdown.
      params["lang"] = language
    }

    if let translation = translation, !translation.isEmpty {
      // Best-effort: web "Перевод" (translation type) dropdown.
      params["translation"] = translation
    }

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
