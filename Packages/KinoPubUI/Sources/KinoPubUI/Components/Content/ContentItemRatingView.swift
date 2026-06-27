//
//  ContentItemRatingView.swift
//
//
//  Created by Kirill Kunst on 24.07.2023.
//

import Foundation
import SwiftUI
import SkeletonUI
/// Shared brand colours for the IMDb / Kinopoisk / kino.pub badges.
public enum RatingBrand {
  public static let imdbGold = Color(red: 0.96, green: 0.77, blue: 0.09)   // #F5C518
  public static let kinopoiskOrange = Color(red: 1.0, green: 0.40, blue: 0.0) // #FF6600
  public static let kinopubTeal = Color(red: 0.11, green: 0.80, blue: 0.59) // kino.pub brand green
}

/// A small coloured "IMDb" / "КП" chip, reused by the tiles, the detail hero and the info block.
public struct RatingBadge: View {
  private let text: String
  private let background: Color
  private let foreground: Color

  public init(text: String, background: Color, foreground: Color) {
    self.text = text
    self.background = background
    self.foreground = foreground
  }

  public static var imdb: RatingBadge { RatingBadge(text: "IMDb", background: RatingBrand.imdbGold, foreground: .black) }
  public static var kinopoisk: RatingBadge { RatingBadge(text: "КП", background: RatingBrand.kinopoiskOrange, foreground: .white) }
  public static var kinopub: RatingBadge { RatingBadge(text: "kino.pub", background: RatingBrand.kinopubTeal, foreground: .black) }

  public var body: some View {
    Text(text)
      .font(.system(size: 10, weight: .heavy))
      .foregroundStyle(foreground)
      .padding(.horizontal, 4)
      .padding(.vertical, 2)
      .background(RoundedRectangle(cornerRadius: 3, style: .continuous).fill(background))
  }
}

/// "[КП] 8.5 / 334,457   [IMDb] 8.1 / 675,834" — the detailed ratings line for the info block.
public struct RatingsDetailRow: View {
  private let kinopubScore: Double?
  private let kinopubVotes: Int?
  private let imdbScore: Double?
  private let imdbVotes: Int?
  private let kinopoiskScore: Double?
  private let kinopoiskVotes: Int?

  public init(kinopubScore: Double? = nil, kinopubVotes: Int? = nil,
              imdbScore: Double?, imdbVotes: Int?, kinopoiskScore: Double?, kinopoiskVotes: Int?) {
    self.kinopubScore = kinopubScore
    self.kinopubVotes = kinopubVotes
    self.imdbScore = imdbScore
    self.imdbVotes = imdbVotes
    self.kinopoiskScore = kinopoiskScore
    self.kinopoiskVotes = kinopoiskVotes
  }

  public var body: some View {
    // Wrap to a second line on narrow screens instead of overflowing the edge.
    FlowLayout(spacing: 18, lineSpacing: 10) {
      if (kinopoiskScore ?? 0) > 0 {
        item(RatingBadge.kinopoisk, score: kinopoiskScore!, votes: kinopoiskVotes)
      }
      if (imdbScore ?? 0) > 0 {
        item(RatingBadge.imdb, score: imdbScore!, votes: imdbVotes)
      }
      if (kinopubScore ?? 0) > 0 {
        item(RatingBadge.kinopub, score: kinopubScore!, votes: kinopubVotes)
      }
    }
  }

  private func item(_ badge: RatingBadge, score: Double, votes: Int?) -> some View {
    HStack(spacing: 6) {
      badge
      Text(RatingsDetailRow.text(score: score, votes: votes))
        .font(.system(size: 14))
        .foregroundStyle(Color.KinoPub.text)
    }
  }

  private static func text(score: Double, votes: Int?) -> String {
    let scoreString = score.scoreFormatted
    guard let votes, votes > 0 else { return scoreString }
    let votesString = NumberFormatter.localizedString(from: NSNumber(value: votes), number: .decimal)
    return "\(scoreString) / \(votesString)"
  }
}

public struct ContentItemRatingView: View {

  var imdbScore: Double?
  var kinopoiskScore: Double?
  /// kino.pub's own rating (0–10). Defaults to nil so poster tiles stay unchanged; the detail hero
  /// passes it so the app surfaces its own score alongside IMDb / Kinopoisk.
  var kinopubScore: Double?

  /// When false, the rounded background "pill" is dropped (e.g. on the detail hero where the
  /// badges sit directly on the artwork).
  var showsBackground: Bool = true

  public init(imdbScore: Double?, kinopoiskScore: Double?, kinopubScore: Double? = nil, showsBackground: Bool = true) {
    self.imdbScore = imdbScore
    self.kinopoiskScore = kinopoiskScore
    self.kinopubScore = kinopubScore
    self.showsBackground = showsBackground
  }

  // Brand colours.
  private static let imdbGold = RatingBrand.imdbGold
  private static let kinopoiskOrange = RatingBrand.kinopoiskOrange

  @ViewBuilder
  public var body: some View {
    if isEmpty {
      // No real ratings — don't show the banner at all.
      EmptyView()
    } else {
      HStack(spacing: 5) {
        if hasKinopoisk {
          badge("КП", background: Self.kinopoiskOrange, foreground: .white)
          score(kinopoiskScore)
        }
        if hasImdb {
          badge("IMDb", background: Self.imdbGold, foreground: .black)
          score(imdbScore)
        }
        // kino.pub's own score sits last, set apart by a thin divider — closest to the like control.
        if hasKinopub {
          if hasKinopoisk || hasImdb {
            RoundedRectangle(cornerRadius: 0.5)
              .fill(Color.white.opacity(0.18))
              .frame(width: 1, height: 13)
              .padding(.horizontal, 3)
          }
          badge("kino.pub", background: RatingBrand.kinopubTeal, foreground: .black)
          score(kinopubScore)
        }
      }
      .padding(.horizontal, showsBackground ? 10 : 0)
      .padding(.vertical, showsBackground ? 4 : 0)
      .background {
        if showsBackground {
          Color.KinoPub.selectionBackground
        }
      }
      .cornerRadius(showsBackground ? 8 : 0)
    }
  }

  // A score of nil or 0 means "no rating" — hide that source.
  private var hasImdb: Bool { (imdbScore ?? 0) > 0 }
  private var hasKinopoisk: Bool { (kinopoiskScore ?? 0) > 0 }
  private var hasKinopub: Bool { (kinopubScore ?? 0) > 0 }

  var isEmpty: Bool {
    !hasImdb && !hasKinopoisk && !hasKinopub
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
