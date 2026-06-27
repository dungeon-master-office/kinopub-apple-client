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
        ratingSlider(title: "From".localized, value: $model.kinopoiskMin)
      }
    }
  }

  var imdbRatingSection: some View {
    Section {
      Toggle("IMDB Rating".localized, isOn: $model.imdbFilterEnabled)
      if model.imdbFilterEnabled {
        ratingSlider(title: "From".localized, value: $model.imdbMin)
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

  func ratingSlider(title: String, value: Binding<Double>) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(title)
        Spacer()
        Text(String(format: "%.1f", value.wrappedValue))
          .foregroundStyle(Color.KinoPub.accent)
          .monospacedDigit()
      }
      // 0…10 in 0.1 steps.
      Slider(value: value, in: 0...10, step: 0.1)
        .tint(Color.KinoPub.accent)
    }
  }
}

