//
//  SeasonItemView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 10.11.2023.
//

import Foundation
import SwiftUI
import KinoPubBackend
import KinoPubUI

public struct SeasonItemView: View {

  private var episode: Episode
  private var onDownload: ((FileInfo) -> Void)?
  @State private var showDownloadPicker: Bool = false

  init(episode: Episode, onDownload: ((FileInfo) -> Void)? = nil) {
    self.episode = episode
    self.onDownload = onDownload
  }

  public var body: some View {
    VStack(alignment: .center) {
      ZStack(alignment: .topTrailing) {
        image
        VStack {
          Spacer()
          title
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
        HStack(spacing: 6) {
          watchIndicator
          if onDownload != nil {
            downloadButton
          }
        }
        .padding(6)
      }
    }
    .background(Color.clear)
  }

  var image: some View {
    CachedAsyncImage(url: URL(string: episode.thumbnail)) { image in
      image.resizable()
        .renderingMode(.original)
        .posterStyle(size: .regular, orientation: .horizontal)
    } placeholder: {
      Color.KinoPub.skeleton
        .frame(width: PosterStyle.Size.regular.height,
               height: PosterStyle.Size.regular.width)
    }
    .cornerRadius(8)
  }

  var title: some View {
    Text(episode.fixedTitle)
      .padding(.vertical, 3)
      .padding(.horizontal, 6)
      .font(.system(size: 14.0, weight: .medium))
      .foregroundStyle(Color.KinoPub.text)
      .background(Color.black.opacity(0.7))

  }

  // Watched (server flag OR watched-to-the-credits) vs only partially watched — via the shared
  // `Episode.isWatched`, so the season list agrees with Continue Watching and the detail page.
  @ViewBuilder
  var watchIndicator: some View {
    if episode.isWatched {
      indicatorImage(systemName: "eye.fill")
    } else if episode.watching.time > 0 {
      indicatorImage(systemName: "circle.lefthalf.filled")
    }
  }

  func indicatorImage(systemName: String) -> some View {
    Image(systemName: systemName)
      .font(.system(size: 18))
      .foregroundStyle(Color.KinoPub.accent)
      .padding(4)
      .background(Color.black.opacity(0.6))
      .clipShape(Circle())
  }

  var downloadButton: some View {
    Button(action: { showDownloadPicker = true }, label: {
      indicatorImage(systemName: "arrow.down.circle")
    })
    .buttonStyle(.plain)
    // Picker to select quality of the episode to download
    .confirmationDialog("", isPresented: $showDownloadPicker, titleVisibility: .hidden) {
      ForEach(episode.files.dedupedByQuality) { file in
        Button(file.quality) {
          onDownload?(file)
        }
      }
    }
  }

}
