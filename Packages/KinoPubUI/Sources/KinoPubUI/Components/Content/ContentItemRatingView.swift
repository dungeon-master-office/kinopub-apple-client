//
//  ContentItemRatingView.swift
//
//
//  Created by Kirill Kunst on 24.07.2023.
//

import Foundation
import SwiftUI
import SkeletonUI
public struct ContentItemRatingView: View {

  var imdbScore: Double?
  var kinopoiskScore: Double?

  // Brand colours.
  private static let imdbGold = Color(red: 0.96, green: 0.77, blue: 0.09)   // #F5C518
  private static let kinopoiskOrange = Color(red: 1.0, green: 0.40, blue: 0.0) // #FF6600

  @ViewBuilder
  public var body: some View {
    if isEmpty {
      // No real ratings — don't show the banner at all.
      EmptyView()
    } else {
      HStack(spacing: 5) {
        if hasImdb {
          badge("IMDb", background: Self.imdbGold, foreground: .black)
          score(imdbScore)
        }
        if hasKinopoisk {
          badge("КП", background: Self.kinopoiskOrange, foreground: .white)
          score(kinopoiskScore)
        }
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 4)
      .background(Color.KinoPub.selectionBackground)
      .cornerRadius(8)
    }
  }

  // A score of nil or 0 means "no rating" — hide that source.
  private var hasImdb: Bool { (imdbScore ?? 0) > 0 }
  private var hasKinopoisk: Bool { (kinopoiskScore ?? 0) > 0 }

  var isEmpty: Bool {
    !hasImdb && !hasKinopoisk
  }

  private func badge(_ text: String, background: Color, foreground: Color) -> some View {
    Text(text)
      .font(.system(size: 10, weight: .heavy))
      .foregroundStyle(foreground)
      .padding(.horizontal, 4)
      .padding(.vertical, 2)
      .background(RoundedRectangle(cornerRadius: 3, style: .continuous).fill(background))
  }

  private func score(_ value: Double?) -> some View {
    Text(value?.scoreFormatted ?? "0.0")
      .font(.system(size: 13, weight: .semibold))
      .foregroundColor(.white)
  }

}

#Preview {
  ContentItemRatingView(imdbScore: 5.0, kinopoiskScore: 5.0)
}
