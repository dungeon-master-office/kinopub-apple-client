//
//  ContinueWatchingCard.swift
//
//
//  Apple TV-style landscape "Continue Watching" tile (artwork, progress bar, title, play glyph).
//

import SwiftUI

/// A landscape card that mirrors Apple TV's "Continue Watching" tiles: 16:9 artwork with a
/// bottom gradient for legibility, an optional thin progress bar, a small play affordance and
/// the title/subtitle overlaid at the bottom.
public struct ContinueWatchingCard: View {

  private let imageURL: String?
  private let title: String
  private let subtitle: String?
  private let progress: Double?
  private let width: CGFloat

  public init(imageURL: String?,
              title: String,
              subtitle: String? = nil,
              progress: Double? = nil,
              width: CGFloat = 300) {
    self.imageURL = imageURL
    self.title = title
    self.subtitle = subtitle
    self.progress = progress
    self.width = width
  }

  private var artworkHeight: CGFloat { width * 9.0 / 16.0 }

  public var body: some View {
    artwork
      .frame(width: width, height: artworkHeight)
      .clipped()
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay(alignment: .bottom) {
        LinearGradient(colors: [.clear, .black.opacity(0.6)],
                       startPoint: .top,
                       endPoint: .bottom)
          .frame(height: artworkHeight * 0.6)
      }
      .overlay(alignment: .bottomLeading) { overlayContent }
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .frame(width: width, alignment: .leading)
  }

  private var artwork: some View {
    CachedAsyncImage(url: URL(string: imageURL ?? "")) { image in
      image
        .resizable()
        .renderingMode(.original)
        .aspectRatio(contentMode: .fill)
    } placeholder: {
      Color.KinoPub.skeleton
    }
  }

  @ViewBuilder
  private var overlayContent: some View {
    VStack(alignment: .leading, spacing: 4) {
      if let progress {
        GeometryReader { geo in
          ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.3))
            Capsule().fill(Color.KinoPub.accent)
              .frame(width: geo.size.width * min(max(progress, 0), 1))
          }
        }
        .frame(height: 3)
        .padding(.bottom, 4)
      }
      HStack(spacing: 6) {
        Image(systemName: "play.fill")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(.white)
        Text(title)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(.white)
          .lineLimit(1)
      }
      if let subtitle {
        Text(subtitle)
          .font(.caption)
          .foregroundStyle(.white.opacity(0.8))
          .lineLimit(1)
      }
    }
    .padding(12)
    .frame(width: width, alignment: .leading)
  }

  /// Unified loading placeholder reserving the same footprint as a real card.
  public static func placeholder(width: CGFloat = 300) -> some View {
    ContinueWatchingCard(imageURL: nil,
                         title: "Placeholder",
                         subtitle: "Placeholder",
                         progress: 0.4,
                         width: width)
      .redacted(reason: .placeholder)
      .opacity(0.45)
  }
}

struct ContinueWatchingCard_Previews: PreviewProvider {
  static var previews: some View {
    HStack(spacing: 14) {
      ContinueWatchingCard(imageURL: nil,
                           title: "Guardians of the Galaxy Vol. 3",
                           subtitle: "1:23:45",
                           progress: 0.4)
      ContinueWatchingCard(imageURL: nil,
                           title: "No Progress Title",
                           subtitle: nil,
                           progress: nil)
    }
    .padding()
    .background(Color.KinoPub.background)
  }
}
