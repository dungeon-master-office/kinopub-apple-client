//
//  FilterModel.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 4.08.2023.
//

import Foundation
import SwiftUI
import KinoPubBackend

/// Lightweight value describing the active catalog filter consumed by `MediaCatalog`.
struct MediaItemsFilter: Equatable {
  var contentType: MediaType
  var genres: [Int]
  var countries: [Int]
  var year: String?
  var sort: String?
}

class FilterModel: ObservableObject {

  @Published var mediaType: MediaType = .movie

  @Published var yearFilterEnabled: Bool = false
  @Published var yearMin: Int = 1920
  @Published var yearMax: Int = 2023

  @Published var imdbFilterEnabled: Bool = false
  @Published var imdbMin: Int = 0
  @Published var imdbMax: Int = 0

  @Published var selectedGenre: MediaGenre?
  @Published var selectedCountry: Country?

  /// Builds the filter value reflecting the user's current selections.
  func makeFilter() -> MediaItemsFilter {
    var year: String?
    if yearFilterEnabled {
      year = yearMin == yearMax ? "\(yearMin)" : "\(yearMin)-\(yearMax)"
    }

    var genres: [Int] = []
    if let selectedGenre = selectedGenre {
      genres.append(selectedGenre.id)
    }

    var countries: [Int] = []
    if let selectedCountry = selectedCountry {
      countries.append(selectedCountry.id)
    }

    return MediaItemsFilter(contentType: mediaType,
                            genres: genres,
                            countries: countries,
                            year: year,
                            sort: nil)
  }

  /// Resets selections to their defaults.
  func clear() {
    mediaType = .movie
    yearFilterEnabled = false
    yearMin = 1920
    yearMax = 2023
    imdbFilterEnabled = false
    imdbMin = 0
    imdbMax = 0
    selectedGenre = nil
    selectedCountry = nil
  }

}
