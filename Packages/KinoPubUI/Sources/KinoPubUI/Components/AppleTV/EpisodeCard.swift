//
//  EpisodeCard.swift
//
//
//  Apple TV-style landscape episode card (thumbnail, overline, title, summary, footnote).
//

import SwiftUI

public struct EpisodeCard: View {

  private let imageURL: String?
  private let overline: String?
  private let title: String
  private let summary: String?
  private let footnote: String?
  private let progress: Double?
  private let width: CGFloat
  private let onMore: (() -> Void)?

  public init(imageURL: String?,
              overline: String? = nil,
              title: String,
              summary: String? = nil,
              footnote: String? = nil,
              progress: Double? = nil,
              width: CGFloat = 300,
              onMore: (() -> Void)? = nil) {
    self.imageURL = imageURL
    self.overline = overline
    self.title = title
    self.summary = summary
    self.footnote = footnote
    self.progress = progress
    self.width = width
    self.onMore = onMore
  }

  private var thumbnailHeight: CGFloat { width * 9.0 / 16.0 }

  public var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      thumbnail
      if let overline {
        Text(overline.uppercased())
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(Color.KinoPub.subtitle)
      }
      Text(title)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(Color.KinoPub.text)
        .lineLimit(1)
      if let summary {
        Text(summary)
          .font(.system(size: 13))
          .foregroundStyle(Color.KinoPub.subtitle)
          .lineLimit(3)
          .multilineTextAlignment(.leading)
      }
      HStack {
        if let footnote {
          Text(footnote)
            .font(.system(size: 12))
            .foregroundStyle(Color.KinoPub.subtitle)
        }
        Spacer(minLength: 0)
        if let onMore {
          Button(action: onMore) {
            Image(systemName: "ellipsis")
              .font(.system(size: 14, weight: .bold))
              .foregroundStyle(Color.KinoPub.subtitle)
          }
          .buttonStyle(.plain)
        }
      }
    }
    .frame(width: width, alignment: .leading)
  }

  private var thumbnail: some View {
    CachedAsyncImage(url: URL(string: imageURL ?? "")) { image in
      image
        .resizable()
        .renderingMode(.original)
        .aspectRatio(contentMode: .fill)
    } placeholder: {
      Color.KinoPub.skeleton
    }
    .frame(width: width, height: thumbnailHeight)
    .clipped()
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(alignment: .bottom) {
      if let progress, progress > 0 {
        GeometryReader { geo in
          ZStack(alignment: .leading) {
            Rectangle().fill(Color.white.opacity(0.3))
            Rectangle().fill(Color.KinoPub.accent)
              .frame(width: geo.size.width * min(max(progress, 0), 1))
          }
        }
        .frame(height: 4)
        .clipShape(Capsule())
        .padding(8)
      }
    }
  }
}
