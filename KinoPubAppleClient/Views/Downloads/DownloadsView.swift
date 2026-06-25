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
  
  init(catalog: @autoclosure @escaping () -> DownloadsCatalog) {
    _catalog = StateObject(wrappedValue: catalog())
  }
  
  var body: some View {
    NavigationStack(path: $navigationState.downloadsRoutes) {
      ZStack {
        if catalog.isEmpty {
          emptyView
        } else {
          downloadsList
        }
      }
      .kinoScreen("Downloads".localized)
      .moreBackButton()
      .routeDestinations()
      .onAppear(perform: {
        catalog.refresh()
      })
    }
    
  }
  
  var downloadsList: some View {
    List {
      activeDownloadsList
      hlsActiveList
      downloadedFilesList
      hlsCompletedList
    }
    .listStyle(.inset)
    .scrollContentBackground(.hidden)
    .background(Color.KinoPub.background)
  }

  /// In-progress HLS downloads (offline, with all tracks/subs). Not navigable until finished.
  var hlsActiveList: some View {
    ForEach(catalog.hlsActive) { download in
      DownloadedItemView(mediaItem: download.meta, progress: download.progress) { _ in }
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
    }
    .onDelete(perform: { indexSet in
      catalog.deleteDownloadedItem(at: indexSet)
    })
    .listRowBackground(Color.KinoPub.background)
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
