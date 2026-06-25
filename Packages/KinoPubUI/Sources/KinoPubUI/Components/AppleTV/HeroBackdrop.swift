//
//  HeroBackdrop.swift
//
//
//  Apple TV-style cinematic hero header: full-bleed backdrop with a frosted/gradient
//  fade into the background and an overlay slot for title / metadata / actions.
//

import SwiftUI

public struct HeroBackdrop<Overlay: View>: View {

  private let imageURL: String?
  private let height: CGFloat
  private let tallBlur: Bool
  private let blurReduction: CGFloat
  private let overlay: Overlay

  public init(imageURL: String?,
              height: CGFloat = 460,
              tallBlur: Bool = false,
              blurReduction: CGFloat = 0,
              @ViewBuilder overlay: () -> Overlay) {
    self.imageURL = imageURL
    self.height = height
    self.tallBlur = tallBlur
    self.blurReduction = blurReduction
    self.overlay = overlay()
  }

  public var body: some View {
    // A base view pinned to the available width keeps every layer (artwork, scrims,
    // and the bottom-leading overlay) anchored to the screen, so the title/actions never
    // get pushed off-screen when the backdrop is wider than the viewport (e.g. in portrait).
    Color.KinoPub.background
      .frame(maxWidth: .infinity)
      .frame(height: height)
      .overlay {
        CachedAsyncImage(url: URL(string: imageURL ?? "")) { image in
          image
            .resizable()
            .renderingMode(.original)
            .aspectRatio(contentMode: .fill)
        } placeholder: {
          Color.KinoPub.skeleton
        }
      }
      .overlay(alignment: .bottom) {
        // Frosted blur over the lower portion so overlay text never mixes with busy artwork.
        // `tallBlur` covers ~bottom two-thirds (detail page); default covers ~bottom third
        // (Home gallery). `blurReduction` shortens the blurred area from the top by N points.
        Rectangle()
          .fill(.ultraThinMaterial)
          .frame(height: max(height - blurReduction, 0))
          .mask(
            LinearGradient(colors: tallBlur ? [.clear, .black, .black] : [.clear, .clear, .black],
                           startPoint: .top,
                           endPoint: .bottom)
          )
      }
      .overlay {
        LinearGradient(
          colors: [
            Color.KinoPub.background.opacity(0.0),
            Color.KinoPub.background.opacity(0.5),
            Color.KinoPub.background
          ],
          startPoint: .center,
          endPoint: .bottom
        )
      }
      .overlay(alignment: .bottomLeading) {
        overlay
          .padding(.horizontal, 20)
          .padding(.bottom, 16)
      }
      .frame(height: height)
      .clipped()
      .allowsHitTesting(true)
  }
}
