//
//  FilterModel.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 4.08.2023.
//

import Foundation
import SwiftUI
import KinoPubBackend
import OSLog
import KinoPubLogging

/// Lightweight value describing the active catalog filter consumed by `MediaCatalog`.
struct MediaItemsFilter: Equatable, Hashable {
  var contentType: MediaType
  var genres: [Int]
  var countries: [Int]
  var year: String?
  var age: String?
  var sort: String?

  // Extended web-filter parameters. All optional so existing call sites keep working.
  var subtitles: String?
  /// Minimum Kinopoisk rating (0...10), when set.
  var kinopoiskMin: Int?
  /// Minimum IMDb rating (0...10), when set.
  var imdbMin: Int?
  var period: String?
  var wantHD: Bool = false
  var withoutHD: Bool = false
  var want4K: Bool = false
  var wantAC3: Bool = false

  /// Number of active filter facets (drives the toolbar badge). Excludes sort/type.
  var activeCount: Int {
    var count = 0
    if !genres.isEmpty { count += 1 }
    if !countries.isEmpty { count += 1 }
    if year != nil { count += 1 }
    if subtitles != nil { count += 1 }
    if (kinopoiskMin ?? 0) > 0 { count += 1 }
    if (imdbMin ?? 0) > 0 { count += 1 }
    if period != nil { count += 1 }
    if wantHD { count += 1 }
    if withoutHD { count += 1 }
    if want4K { count += 1 }
    if wantAC3 { count += 1 }
    return count
  }

  // MARK: - Best-effort backend param mappings (see FilterItemsRequest for caveats)

  var imdbParam: String? {
    guard let imdbMin, imdbMin > 0 else { return nil }
    return "\(imdbMin)"
  }

  var kinopoiskParam: String? {
    guard let kinopoiskMin, kinopoiskMin > 0 else { return nil }
    return "\(kinopoiskMin)"
  }

  /// HD / 4K quality identifiers (best-effort).
  var qualityParams: [String]? {
    var values: [String] = []
    if wantHD { values.append("hd") }
    if want4K { values.append("4k") }
    return values.isEmpty ? nil : values
  }

  /// HD-exclusion / AC3 conditions (best-effort).
  var conditionParams: [String]? {
    var values: [String] = []
    if withoutHD { values.append("without_hd") }
    if wantAC3 { values.append("ac3") }
    return values.isEmpty ? nil : values
  }
}

@MainActor
class FilterModel: ObservableObject {

  /// The section's content type. Set from the catalog and NOT user-editable
  /// (you can't switch type from inside a section — that was the bug).
  let contentType: MediaType

  private let filterDataService: VideoContentService?

  @Published var genres: [MediaGenre] = []
  @Published var countries: [Country] = []

  @Published var selectedGenre: MediaGenre?
  @Published var selectedCountry: Country?

  @Published var subtitles: String = SubtitlesOption.any.rawValue
  @Published var sort: String = SortOption.updated.rawValue
  @Published var period: String = PeriodOption.any.rawValue

  @Published var yearFilterEnabled: Bool = false
  @Published var yearMin: Int = 1912
  @Published var yearMax: Int = 2026

  @Published var kinopoiskFilterEnabled: Bool = false
  @Published var kinopoiskMin: Int = 0

  @Published var imdbFilterEnabled: Bool = false
  @Published var imdbMin: Int = 0

  @Published var wantHD: Bool = false
  @Published var withoutHD: Bool = false
  @Published var want4K: Bool = false
  @Published var wantAC3: Bool = false

  init(contentType: MediaType = .movie,
       filterDataService: VideoContentService? = nil) {
    self.contentType = contentType
    self.filterDataService = filterDataService
    Task { await loadOptions() }
  }

  /// Loads genres (scoped to the section type) and countries for the pickers.
  func loadOptions() async {
    guard let filterDataService else { return }
    do {
      genres = try await filterDataService.fetchGenres(type: contentType)
    } catch {
      Logger.app.debug("filter: fetch genres error: \(error)")
    }
    do {
      countries = try await filterDataService.fetchCountries()
    } catch {
      // Country options are optional; fall back to "Any" only.
      Logger.app.debug("filter: fetch countries error: \(error)")
    }
  }

  /// Builds the filter value reflecting the user's current selections.
  func makeFilter() -> MediaItemsFilter {
    var year: String?
    if yearFilterEnabled {
      year = yearMin == yearMax ? "\(yearMin)" : "\(yearMin)-\(yearMax)"
    }

    var genreIds: [Int] = []
    if let selectedGenre = selectedGenre {
      genreIds.append(selectedGenre.id)
    }

    var countryIds: [Int] = []
    if let selectedCountry = selectedCountry {
      countryIds.append(selectedCountry.id)
    }

    return MediaItemsFilter(contentType: contentType,
                            genres: genreIds,
                            countries: countryIds,
                            year: year,
                            age: nil,
                            sort: sort == SortOption.updated.rawValue ? nil : sort,
                            subtitles: subtitles == SubtitlesOption.any.rawValue ? nil : subtitles,
                            kinopoiskMin: kinopoiskFilterEnabled ? kinopoiskMin : nil,
                            imdbMin: imdbFilterEnabled ? imdbMin : nil,
                            period: period == PeriodOption.any.rawValue ? nil : period,
                            wantHD: wantHD,
                            withoutHD: withoutHD,
                            want4K: want4K,
                            wantAC3: wantAC3)
  }

  /// Resets selections to their defaults.
  func clear() {
    selectedGenre = nil
    selectedCountry = nil
    subtitles = SubtitlesOption.any.rawValue
    sort = SortOption.updated.rawValue
    period = PeriodOption.any.rawValue
    yearFilterEnabled = false
    yearMin = 1912
    yearMax = 2026
    kinopoiskFilterEnabled = false
    kinopoiskMin = 0
    imdbFilterEnabled = false
    imdbMin = 0
    wantHD = false
    withoutHD = false
    want4K = false
    wantAC3 = false
  }
}

// MARK: - Dropdown option enums (mirror the web filter)

/// Sort field for the catalog (suffix `-` = DESC per kino.pub API).
enum SortOption: String, CaseIterable, Identifiable {
  case updated = "updated-"
  case created = "created-"
  case year = "year-"
  case title = "title"
  case rating = "rating-"
  case views = "views-"
  case watchers = "watchers-"

  var id: String { rawValue }

  /// Localization key (resolved with `.localized`).
  var titleKey: String {
    switch self {
    case .updated: return "Date updated"
    case .created: return "Date created"
    case .year: return "Year"
    case .title: return "Title"
    case .rating: return "Rating"
    case .views: return "Views"
    case .watchers: return "Watchers"
    }
  }
}

/// Subtitles availability (best-effort param values).
enum SubtitlesOption: String, CaseIterable, Identifiable {
  case any = ""
  case withSubtitles = "1"

  var id: String { rawValue }

  var titleKey: String {
    switch self {
    case .any: return "Any"
    case .withSubtitles: return "With subtitles"
    }
  }
}

/// "Period" dropdown (best-effort param values).
enum PeriodOption: String, CaseIterable, Identifiable {
  case any = ""
  case day = "day"
  case week = "week"
  case month = "month"
  case year = "year"

  var id: String { rawValue }

  var titleKey: String {
    switch self {
    case .any: return "Any time"
    case .day: return "Day"
    case .week: return "Week"
    case .month: return "Month"
    case .year: return "Year"
    }
  }
}
