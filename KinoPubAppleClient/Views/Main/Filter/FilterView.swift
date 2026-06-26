//
//  FilterView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 4.08.2023.
//

import Foundation
import SwiftUI
import KinoPubBackend
import KinoPubUI

struct FilterView: View {

  @Environment(\.dismiss) private var dismiss
  @StateObject private var model: FilterModel

  private let onApply: (MediaItemsFilter) -> Void
  private let onClear: () -> Void

  private let yearRange = Array(1912...2026)
  private let ratingRange = Array(0...10)

  init(model: @autoclosure @escaping () -> FilterModel,
       onApply: @escaping (MediaItemsFilter) -> Void = { _ in },
       onClear: @escaping () -> Void = {}) {
    _model = StateObject(wrappedValue: model())
    self.onApply = onApply
    self.onClear = onClear
  }

  var body: some View {
    NavigationStack {
      Form {
        genreSection
        countrySection
        subtitlesSortPeriodSection
        yearSection
        kinopoiskRatingSection
        imdbRatingSection
        qualitySection
      }
      .formStyle(.grouped)
      .scrollContentBackground(.hidden)
      .background(Color.KinoPub.background)
      .navigationTitle("Filter".localized)
      #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Clear".localized, role: .destructive) {
            model.clear()
            onClear()
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Apply".localized) {
            onApply(model.makeFilter())
            dismiss()
          }
        }
      }
    }
    .presentationDetents([.medium, .large])
  }

  // MARK: - Genre / Country

  var genreSection: some View {
    Section {
      Picker("Genre".localized, selection: $model.selectedGenre) {
        Text("Any".localized).tag(MediaGenre?.none)
        ForEach(model.genres) { genre in
          Text(genre.title).tag(MediaGenre?.some(genre))
        }
      }
      .pickerStyle(.menu)
    }
  }

  @ViewBuilder
  var countrySection: some View {
    if !model.countries.isEmpty {
      Section {
        Picker("Country".localized, selection: $model.selectedCountry) {
          Text("Any".localized).tag(Country?.none)
          ForEach(model.countries) { country in
            Text(country.title).tag(Country?.some(country))
          }
        }
        .pickerStyle(.menu)
      }
    }
  }

  // MARK: - Subtitles / Sort / Period

  var subtitlesSortPeriodSection: some View {
    Section {
      Picker("Subtitles".localized, selection: $model.subtitles) {
        ForEach(SubtitlesOption.allCases) { option in
          Text(option.titleKey.localized).tag(option.rawValue)
        }
      }
      .pickerStyle(.menu)

      Picker("Sort".localized, selection: $model.sort) {
        ForEach(SortOption.allCases) { option in
          Text(option.titleKey.localized).tag(option.rawValue)
        }
      }
      .pickerStyle(.menu)

      Picker("Period".localized, selection: $model.period) {
        ForEach(PeriodOption.allCases) { option in
          Text(option.titleKey.localized).tag(option.rawValue)
        }
      }
      .pickerStyle(.menu)

      Picker("Language".localized, selection: $model.language) {
        ForEach(LanguageOption.allCases) { option in
          Text(option.titleKey.localized).tag(option.rawValue)
        }
      }
      .pickerStyle(.menu)

      Picker("Translation".localized, selection: $model.translation) {
        ForEach(TranslationOption.allCases) { option in
          Text(option.titleKey.localized).tag(option.rawValue)
        }
      }
      .pickerStyle(.menu)

      Picker("Age".localized, selection: $model.age) {
        ForEach(AgeOption.allCases) { option in
          Text(option.titleKey.localized).tag(option.rawValue)
        }
      }
      .pickerStyle(.menu)
    }
  }

  // MARK: - Year range

  var yearSection: some View {
    Section {
      Toggle("Release Year".localized, isOn: $model.yearFilterEnabled)
      if model.yearFilterEnabled {
        yearPicker(title: "From".localized, selection: $model.yearMin)
        yearPicker(title: "To".localized, selection: $model.yearMax)
      }
    }
  }

  // MARK: - Ratings

  var kinopoiskRatingSection: some View {
    Section {
      Toggle("Kinopoisk Rating".localized, isOn: $model.kinopoiskFilterEnabled)
      if model.kinopoiskFilterEnabled {
        ratingPicker(title: "From".localized, selection: $model.kinopoiskMin)
      }
    }
  }

  var imdbRatingSection: some View {
    Section {
      Toggle("IMDB Rating".localized, isOn: $model.imdbFilterEnabled)
      if model.imdbFilterEnabled {
        ratingPicker(title: "From".localized, selection: $model.imdbMin)
      }
    }
  }

  // MARK: - Quality checkboxes

  var qualitySection: some View {
    Section {
      Toggle("Want HD".localized, isOn: $model.wantHD)
      Toggle("Without HD".localized, isOn: $model.withoutHD)
      Toggle("Want 4K".localized, isOn: $model.want4K)
      Toggle("Want AC3".localized, isOn: $model.wantAC3)
    }
  }

  // MARK: - Helpers

  func yearPicker(title: String, selection: Binding<Int>) -> some View {
    Picker(title, selection: selection) {
      ForEach(yearRange, id: \.self) { year in
        Text(verbatim: "\(year)").tag(year)
      }
    }
    .pickerStyle(.menu)
  }

  func ratingPicker(title: String, selection: Binding<Int>) -> some View {
    Picker(title, selection: selection) {
      ForEach(ratingRange, id: \.self) { value in
        Text(verbatim: "\(value)").tag(value)
      }
    }
    .pickerStyle(.menu)
  }
}

