//
//  DownloadsView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 22.07.2023.
//

import SwiftUI
import KinoPubBackend
import KinoPubKit
import KinoPubUI

struct DownloadsView: View {
  
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var errorHandler: ErrorHandler
  @Environment(\.appContext) var appContext
  @StateObject private var catalog: DownloadsCatalog
  @Environment(\.sectionEmbedded) private var sectionEmbedded

  init(catalog: @autoclosure @escaping () -> DownloadsCatalog) {
    _catalog = StateObject(wrappedValue: catalog())
  }

  var body: some View {
    if sectionEmbedded {
      sectionContent
    } else {
      NavigationStack(path: $navigationState.downloadsRoutes) {
        sectionContent.routeDestinations()
      }
    }
  }

  private var sectionContent: some View {
    ZStack {
      if catalog.isEmpty {
        emptyView
      } else {
        downloadsList
      }
    }
    .kinoScreen("Downloads".localized)
    .onAppear(perform: {
      catalog.refresh()
    })
  }
  
  private var hasActive: Bool { !catalog.activeDownloads.isEmpty || !catalog.hlsActive.isEmpty }
  private var hasCompleted: Bool { !catalog.downloadedItems.isEmpty || !catalog.hlsCompleted.isEmpty }

  var downloadsList: some View {
    List {
      if hasActive {
        Section {
          activeDownloadsList
          hlsActiveList
        } header: { sectionHeader("Active") }
      }
      if !catalog.hlsInterrupted.isEmpty {
        Section {
          hlsInterruptedList
        } header: { sectionHeader("Interrupted") }
      }
      if hasCompleted {
        Section {
          downloadedFilesList
          hlsCompletedList
        } header: { sectionHeader("Downloaded") }
      }
    }
    .listStyle(.inset)
    .scrollContentBackground(.hidden)
    .background(Color.KinoPub.background)
  }

  /// Floating glass-capsule section header — matches the History sticky headers (Liquid Glass on OS 26).
  private func sectionHeader(_ key: String) -> some View {
    Text(key.localized)
      .font(.system(size: 14, weight: .semibold))
      .foregroundStyle(Color.KinoPub.text)
      .textCase(nil)
      .padding(.horizontal, 14)
      .padding(.vertical, 7)
      .glassCapsule()
      .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 6, trailing: 4))
      .listRowBackground(Color.clear)
  }

  /// Interrupted HLS downloads (force-quit). Tap to re-download; swipe to dismiss + clean up.
  var hlsInterruptedList: some View {
    ForEach(catalog.hlsInterrupted) { item in
      Button {
        catalog.retryHLSInterrupted(item)
      } label: {
        DownloadedItemView(mediaItem: item.meta, progress: nil, state: .interrupted) { _ in }
      }
      .buttonStyle(.plain)
      .contextMenu { detailLink(for: item.meta) }
    }
    .onDelete(perform: { catalog.dismissHLSInterrupted(at: $0) })
    .listRowBackground(Color.KinoPub.background)
  }

  /// In-progress HLS downloads (offline, with all tracks/subs). Not navigable until finished.
  var hlsActiveList: some View {
    ForEach(catalog.hlsActive) { download in
      DownloadedItemView(mediaItem: download.meta,
                         progress: download.progress,
                         speed: download.speed,
                         remaining: download.remaining) { _ in }
        .contextMenu { detailLink(for: download.meta) }
    }
    .onDelete(perform: { catalog.cancelHLSDownload(at: $0) })
    .listRowBackground(Color.KinoPub.background)
  }

  /// Completed HLS downloads (.movpkg). Tapping opens the player; swipe deletes the bundle.
  var hlsCompletedList: some View {
    ForEach(catalog.hlsCompleted, id: \.relativePath) { asset in
      NavigationLink(value: Route.player(asset.meta)) {
        DownloadedItemView(mediaItem: asset.meta, progress: nil, fileURL: asset.localFileURL) { _ in }
      }
      .contextMenu { detailLink(for: asset.meta) }
    }
    .onDelete(perform: { catalog.deleteHLSCompleted(at: $0) })
    .listRowBackground(Color.KinoPub.background)
  }

  var activeDownloadsList: some View {
    // In-progress downloads are NOT navigable (file isn't ready) — so the pause/resume button
    // is tappable instead of the whole row opening the player.
    ForEach(catalog.activeDownloads, id: \.url) { download in
      DownloadedItemView(mediaItem: download.metadata,
                         progress: download.progress,
                         speed: download.speed,
                         remaining: download.remainingTime) { _ in
        catalog.toggle(download: download)
      }
      .contextMenu { detailLink(for: download.metadata) }
    }
    .onDelete(perform: { indexSet in
      catalog.deleteActiveDownload(at: indexSet)
    })
    .listRowBackground(Color.KinoPub.background)
  }

  var downloadedFilesList: some View {
    ForEach(catalog.downloadedItems, id: \.originalURL) { fileInfo in
      NavigationLink(value: Route.player(fileInfo.metadata)) {
        DownloadedItemView(mediaItem: fileInfo.metadata, progress: nil, fileURL: fileInfo.localFileURL) { _ in }
      }
      .contextMenu { detailLink(for: fileInfo.metadata) }
    }
    .onDelete(perform: { indexSet in
      catalog.deleteDownloadedItem(at: indexSet)
    })
    .listRowBackground(Color.KinoPub.background)
  }

  /// Long-press menu entry to jump from a download to its movie/series detail page.
  /// `DownloadMeta.id` is the series/movie content id, so detailsByID opens the right title.
  @ViewBuilder
  private func detailLink(for meta: DownloadMeta) -> some View {
    // A series episode always carries a season/episode number; a movie has neither — reliable even
    // for older saved entries whose `episode` label may be wrong.
    let isSeries = meta.metadata.season != nil || meta.metadata.video != nil
    NavigationLink(value: Route.detailsByID(meta.id)) {
      Label(isSeries ? "Go to Series".localized : "Go to Movie".localized,
            systemImage: "info.circle")
    }
  }
  
  var emptyView: some View {
    EmptyStateView(systemImage: "arrow.down.circle", title: "You don't have any downloads yet".localized)
      .background(Color.KinoPub.background)
  }
}

struct DownloadsView_Previews: PreviewProvider {
  static var previews: some View {
    
    let database = DownloadedFilesDatabase<DownloadMeta>(fileSaver: FileSaver())
    
    let downloadManager = DownloadManager<DownloadMeta>(fileSaver: FileSaver(), database: database)
    
    DownloadsView(catalog: DownloadsCatalog(downloadsDatabase: database,
                                            downloadManager: downloadManager))
  }
}
