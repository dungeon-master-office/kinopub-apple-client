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
  private var page: Int?

  public init(contentType: MediaType? = nil,
              genres: [Int]? = nil,
              countries: [Int]? = nil,
              year: String? = nil,
              age: String? = nil,
              sort: String? = nil,
              page: Int? = nil) {
    self.contentType = contentType
    self.genres = genres
    self.countries = countries
    self.year = year
    self.age = age
    self.sort = sort
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
