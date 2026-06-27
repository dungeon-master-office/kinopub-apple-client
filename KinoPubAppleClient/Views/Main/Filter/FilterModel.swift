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
  /// Raw `type` override for presets that span several types (e.g. Anime = "movie,serial").
  var rawType: String?
  var genres: [Int]
  var countries: [Int]
  var year: String?
  var age: String?
  var sort: String?
  /// Filter by a director / actor name (used by the "More from … / More with …" detail shelves).
  var director: String?
  var cast: String?

  // Extended web-filter parameters. All optional so existing call sites keep working.
  var subtitles: String?
  /// Minimum Kinopoisk rating (0...10, 0.1 steps), when set.
  var kinopoiskMin: Double?
  /// Minimum IMDb rating (0...10, 0.1 steps), when set.
  var imdbMin: Double?
  var period: String?
  var language: String?
  var translation: String?
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
    if age != nil { count += 1 }
    if subtitles != nil { count += 1 }
    if language != nil { count += 1 }
    if translation != nil { count += 1 }
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
    return String(format: "%g", imdbMin)
  }

  var kinopoiskParam: String? {
    guard let kinopoiskMin, kinopoiskMin > 0 else { return nil }
    return String(format: "%g", kinopoiskMin)
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

  // MARK: - Client-side facets
  //
  // The mobile /v1/items API only honors type/genre/country/year/sort (verified against the live
  // API — the rating/HD/4K/AC3/period filters the web applies server-side are silently ignored).
  // Since each item already carries imdb_rating/kinopoisk_rating/quality/ac3/created_at, we apply
  // those facets on the fetched results instead, so the in-app filter matches the website.

  /// Whether any facet must be applied client-side. (Period is sent server-side now — see
  /// FilterItemsRequest — so it's no longer a client-side facet.)
  var hasClientSideFacets: Bool {
    (imdbMin ?? 0) > 0 || (kinopoiskMin ?? 0) > 0 || wantHD || withoutHD || want4K || wantAC3
  }

  /// Applies the client-side-only facets to a fetched item (`now` is the current unix time).
  func clientSideMatches(_ item: MediaItem, now: TimeInterval) -> Bool {
    if let imdbMin, imdbMin > 0, (item.imdbRating ?? 0) < imdbMin { return false }
    if let kinopoiskMin, kinopoiskMin > 0, (item.kinopoiskRating ?? 0) < kinopoiskMin { return false }
    if wantAC3, (item.ac3 ?? 0) != 1 { return false }
    if want4K, item.quality < 2160 { return false }
    if wantHD, item.quality < 720 { return false }
    if withoutHD, item.quality >= 720 { return false }
    // Period is applied server-side now (see FilterItemsRequest); not approximated by created_at here.
    return true
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
  @Published var age: String = AgeOption.any.rawValue
  @Published var language: String = LanguageOption.any.rawValue
  @Published var translation: String = TranslationOption.any.rawValue

  @Published var yearFilterEnabled: Bool = false
  @Published var yearMin: Int = 1912
  @Published var yearMax: Int = 2026

  @Published var kinopoiskFilterEnabled: Bool = false
  @Published var kinopoiskMin: Double = 0

  @Published var imdbFilterEnabled: Bool = false
  @Published var imdbMin: Double = 0

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
    age = filter.age ?? AgeOption.any.rawValue
    language = filter.language ?? LanguageOption.any.rawValue
    translation = filter.translation ?? TranslationOption.any.rawValue
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
                            age: age == AgeOption.any.rawValue ? nil : age,
                            sort: sort == SortOption.updated.rawValue ? nil : sort,
                            subtitles: subtitles == SubtitlesOption.any.rawValue ? nil : subtitles,
                            kinopoiskMin: kinopoiskFilterEnabled ? kinopoiskMin : nil,
                            imdbMin: imdbFilterEnabled ? imdbMin : nil,
                            period: period == PeriodOption.any.rawValue ? nil : period,
                            language: language == LanguageOption.any.rawValue ? nil : language,
                            translation: translation == TranslationOption.any.rawValue ? nil : translation,
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
    age = AgeOption.any.rawValue
    language = LanguageOption.any.rawValue
    translation = TranslationOption.any.rawValue
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
  case watchers = "watchers-"
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
    case .watchers: return "By watchers"
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

/// Age rating — mirrors the web "Возраст" dropdown (value is the minimum age).
enum AgeOption: String, CaseIterable, Identifiable {
  case any = ""
  case zero = "0"
  case six = "6"
  case twelve = "12"
  case sixteen = "16"
  case eighteen = "18"

  var id: String { rawValue }

  var titleKey: String { self == .any ? "Any" : "\(rawValue)+" }
}

/// Audio language — mirrors the web "Язык" dropdown (best-effort param values).
enum LanguageOption: String, CaseIterable, Identifiable {
  case any = ""
  case russian = "rus"
  case english = "eng"
  case ukrainian = "ukr"
  case french = "fra"
  case german = "ger"
  case spanish = "spa"
  case italian = "ita"
  case portuguese = "por"
  case japanese = "jpn"

  var id: String { rawValue }

  var titleKey: String {
    switch self {
    case .any: return "Any"
    case .russian: return "Russian language"
    case .english: return "English language"
    case .ukrainian: return "Ukrainian language"
    case .french: return "French language"
    case .german: return "German language"
    case .spanish: return "Spanish language"
    case .italian: return "Italian language"
    case .portuguese: return "Portuguese language"
    case .japanese: return "Japanese language"
    }
  }
}

/// Translation type — mirrors the web "Перевод" dropdown (best-effort param values).
enum TranslationOption: String, CaseIterable, Identifiable {
  case any = ""
  case dubbing = "dubbing"
  case multivoice = "multi"
  case twovoice = "two"
  case onevoice = "one"
  case author = "author"
  case original = "original"
  case neural = "neural"

  var id: String { rawValue }

  var titleKey: String {
    switch self {
    case .any: return "Any"
    case .dubbing: return "Dubbing"
    case .multivoice: return "Multi-voice"
    case .twovoice: return "Two-voice"
    case .onevoice: return "One-voice"
    case .author: return "Author"
    case .original: return "Original"
    case .neural: return "Neural"
    }
  }
}
