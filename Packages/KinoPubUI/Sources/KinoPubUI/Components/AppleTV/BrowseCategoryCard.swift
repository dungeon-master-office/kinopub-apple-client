//
//  BrowseCategoryCard.swift
//
//
//  Apple TV-style "Browse" category card: artwork with a label overlaid bottom-leading.
//

import SwiftUI

public struct BrowseCategoryCard: View {

  private let title: String
  private let imageURL: String?
  private let gradientColors: [Color]
  private let height: CGFloat

  public init(title: String,
              imageURL: String? = nil,
              gradientColors: [Color] = [Color.KinoPub.accentBlue, Color.KinoPub.accent],
              height: CGFloat = 130) {
    self.title = title
    self.imageURL = imageURL
    self.gradientColors = gradientColors
    self.height = height
  }

  public var body: some View {
    ZStack(alignment: .bottomLeading) {
      background
      LinearGradient(colors: [.black.opacity(0.0), .black.opacity(0.55)],
                     startPoint: .center,
                     endPoint: .bottom)
      Text(title)
        .font(.system(size: 17, weight: .bold))
        .foregroundStyle(.white)
        .lineLimit(1)
        .padding(12)
    }
    .frame(height: height)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
    )
  }

  @ViewBuilder
  private var background: some View {
    if let imageURL, !imageURL.isEmpty {
      CachedAsyncImage(url: URL(string: imageURL)) { image in
        image.resizable().aspectRatio(contentMode: .fill)
      } placeholder: {
        LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
      }
    } else {
      LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
  }
}
