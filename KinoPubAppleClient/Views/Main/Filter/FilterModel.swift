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

  /// The filter the sheet was opened with, so reopening reflects the applied state.
  private let initialFilter: MediaItemsFilter?

  init(contentType: MediaType = .movie,
       filterDataService: VideoContentService? = nil,
       initialFilter: MediaItemsFilter? = nil) {
    self.contentType = contentType
    self.filterDataService = filterDataService
    self.initialFilter = initialFilter
    applyInitialScalars()
    Task { await loadOptions() }
  }

  /// Restores the non-list selections (sort/subtitles/year/ratings/quality) from the
  /// active filter so the sheet doesn't reset every time it's reopened.
  private func applyInitialScalars() {
    guard let filter = initialFilter else { return }
    sort = filter.sort ?? SortOption.updated.rawValue
    subtitles = filter.subtitles ?? SubtitlesOption.any.rawValue
    period = filter.period ?? PeriodOption.any.rawValue
    if let year = filter.year {
      yearFilterEnabled = true
      let parts = year.split(separator: "-").compactMap { Int($0) }
      yearMin = parts.first ?? yearMin
      yearMax = parts.count > 1 ? parts[1] : (parts.first ?? yearMax)
    }
    if let kp = filter.kinopoiskMin, kp > 0 { kinopoiskFilterEnabled = true; kinopoiskMin = kp }
    if let imdb = filter.imdbMin, imdb > 0 { imdbFilterEnabled = true; imdbMin = imdb }
    wantHD = filter.wantHD
    withoutHD = filter.withoutHD
    want4K = filter.want4K
    wantAC3 = filter.wantAC3
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
    // Now that the lists are loaded, restore the selected genre/country from the active filter.
    if let filter = initialFilter {
      if let genreId = filter.genres.first {
        selectedGenre = genres.first { $0.id == genreId }
      }
      if let countryId = filter.countries.first {
        selectedCountry = countries.first { $0.id == countryId }
      }
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

/// Sort field for the catalog — mirrors the web "Сортировка" dropdown (suffix `-` = DESC).
enum SortOption: String, CaseIterable, Identifiable {
  case updated = "updated-"
  case created = "created-"
  case rating = "rating-"
  case views = "views-"
  case kinopoisk = "kinopoisk_rating-"
  case imdb = "imdb_rating-"

  var id: String { rawValue }

  /// Localization key (resolved with `.localized`).
  var titleKey: String {
    switch self {
    case .updated: return "By update"
    case .created: return "Added"
    case .rating: return "By rating"
    case .views: return "By views"
    case .kinopoisk: return "By Kinopoisk"
    case .imdb: return "By IMDb"
    }
  }
}

/// Subtitle language — mirrors the web "Субтитры" dropdown (it's a language list).
enum SubtitlesOption: String, CaseIterable, Identifiable {
  case any = ""
  case russian = "rus"
  case english = "eng"
  case ukrainian = "ukr"
  case french = "fra"
  case german = "ger"
  case spanish = "spa"
  case italian = "ita"
  case portuguese = "por"
  case finnish = "fin"
  case polish = "pol"

  var id: String { rawValue }

  var titleKey: String {
    switch self {
    case .any: return "Any"
    case .russian: return "Russian"
    case .english: return "English"
    case .ukrainian: return "Ukrainian"
    case .french: return "French"
    case .german: return "German"
    case .spanish: return "Spanish"
    case .italian: return "Italian"
    case .portuguese: return "Portuguese"
    case .finnish: return "Finnish"
    case .polish: return "Polish"
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
