//
//  ContentItemView.swift
//
//
//  Created by Kirill Kunst on 24.07.2023.
//

import Foundation
import SwiftUI
import KinoPubBackend

public struct ContentItemView: View {

  private var mediaItem: MediaItem

  init(mediaItem: MediaItem) {
    self.mediaItem = mediaItem
  }

  private var isPlaceholder: Bool { mediaItem.skeleton ?? false }

  public var body: some View {
    VStack(alignment: .center) {
      ZStack {
        image
        if !isPlaceholder {
          ratingsBlock
        }
      }
      VStack(alignment: .center) {
        title
        subtitle
      }.padding(.horizontal, 8)
    }
    .background(Color.clear)
    // Unified placeholder: native redaction (matches PosterCard.placeholder), no shimmer.
    .redacted(reason: isPlaceholder ? .placeholder : [])
  }

  var image: some View {
    // Fill the grid column width with a 2:3 poster so columns stay even (Apple TV style).
    Color.KinoPub.skeleton
      .aspectRatio(2.0 / 3.0, contentMode: .fit)
      .frame(maxWidth: .infinity)
      .overlay {
        CachedAsyncImage(url: URL(string: mediaItem.posters.medium)) { image in
          image
            .resizable()
            .renderingMode(.original)
            .aspectRatio(contentMode: .fill)
        } placeholder: {
          Color.KinoPub.skeleton
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  var ratingsBlock: some View {
    VStack {
      Spacer()
      ContentItemRatingView(imdbScore: mediaItem.imdbRating,
                            kinopoiskScore: mediaItem.kinopoiskRating)
      .padding(.bottom, 8)
    }
  }

  var title: some View {
    Text(isPlaceholder ? "Placeholder" : mediaItem.localizedTitle)
      .lineLimit(1)
      .font(.system(size: 16.0, weight: .medium))
      .foregroundStyle(Color.KinoPub.text)
  }

  var subtitle: some View {
    Text(isPlaceholder ? "Placeholder" : mediaItem.originalTitle)
      .lineLimit(1)
      .font(.system(size: 14.0, weight: .medium))
      .foregroundStyle(Color.KinoPub.subtitle)
  }

}

#Preview {
  ContentItemView(mediaItem: MediaItem.mock(skeleton: true))
}
