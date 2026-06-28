//
//  MediaCardStatusBadge.swift
//  KinoPubAppleClient
//
//  Unified status corner-badges for a media card (poster/landscape) sourced from the single client
//  library state, so watched / downloaded / downloading reads are identical on every screen. Layered
//  as an overlay at call sites because the card components live in KinoPubUI (which can't see the
//  app's MediaLibraryStore) — this keeps the dependency direction clean.
//

import SwiftUI
import KinoPubBackend
import KinoPubUI

struct MediaCardStatusBadge: View {
  @EnvironmentObject private var libraryState: MediaLibraryStore
  let item: MediaItem
  /// Whether to show the "watched" check (hidden on Continue Watching, where it's redundant).
  var showsWatched: Bool = true

  var body: some View {
    let downloaded = libraryState.isDownloadedAny(itemId: item.id)
    let downloading = !downloaded && libraryState.isDownloadingAny(itemId: item.id)
    let watched = showsWatched
      && !item.isSeries
      && libraryState.movieWatched(itemId: item.id, serverWatched: item.videos?.first?.isWatched ?? false)

    HStack(spacing: 4) {
      if watched { badge("eye.fill") }
      if downloaded {
        badge("arrow.down.circle.fill")
      } else if downloading {
        ProgressView()
          .controlSize(.mini)
          .padding(4)
          .background(Circle().fill(.black.opacity(0.45)))
      }
    }
    .padding(6)
  }

  private func badge(_ systemName: String) -> some View {
    Image(systemName: systemName)
      .font(.system(size: 16, weight: .semibold))
      .foregroundStyle(.white, Color.KinoPub.accent)
      .padding(3)
      .background(Circle().fill(.black.opacity(0.35)))
  }
}
