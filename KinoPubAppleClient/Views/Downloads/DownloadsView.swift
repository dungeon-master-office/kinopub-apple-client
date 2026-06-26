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
  @State private var showStorage = false
  @State private var errorToast: ToastMessage?

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
    .sheet(isPresented: $showStorage, onDismiss: { catalog.refresh() }) {
      StorageBreakdownView()
    }
    .toast(message: $errorToast, duration: 5)
    .onChange(of: catalog.downloadError) { error in
      if let error { errorToast = .error(error) }
    }
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
      if catalog.totalBytes > 0 {
        Button {
          showStorage = true
        } label: {
          HStack {
            Image(systemName: "internaldrive")
            Text("Storage used".localized)
            Spacer()
            Text(ByteCountFormatter.string(fromByteCount: catalog.totalBytes, countStyle: .file))
              .foregroundStyle(Color.KinoPub.subtitle)
            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(Color.KinoPub.subtitle)
          }
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(Color.KinoPub.text)
        }
        .listRowBackground(Color.clear)
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

// MARK: - Storage breakdown

/// A breakdown of the app's on-disk usage so the user can see where space goes (HLS downloads live in
/// Library — invisible to the Files app — and keep every audio track, so they're bigger than the
/// source). Lets the user clear the image cache and sweep orphaned download files.
private struct StorageBreakdownView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.appContext) private var appContext
  @State private var breakdown: StorageUsage?
  @State private var busy = false

  var body: some View {
    NavigationStack {
      List {
        if let breakdown {
          Section {
            row("Downloads".localized, breakdown.downloads)
            row("Image cache".localized, breakdown.imageCache)
            row("Other".localized, breakdown.other)
          } footer: {
            Text("HLS downloads are stored in the app's private storage (not visible in the Files app) and keep every audio track, so they're larger than the source file.".localized)
          }
          Section {
            HStack { Text("Total".localized).bold(); Spacer(); Text(format(breakdown.total)).bold() }
          }
          Section {
            Button("Clear image cache".localized) {
              ImageCache.shared.clear()
              recompute()
            }
            Button("Remove leftover download files".localized) {
              busy = true
              let keep: Set<String> = []
              DispatchQueue.global(qos: .utility).async {
                AppContext.shared.hlsDownloadsStore.sweepOrphans(keepRelativePaths: keep)
                DispatchQueue.main.async { recompute() }
              }
            }
          }
        } else {
          HStack { Spacer(); ProgressView(); Spacer() }
        }
      }
      .navigationTitle("Storage".localized)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done".localized) { dismiss() }
        }
      }
    }
    .onAppear(perform: recompute)
  }

  private func row(_ title: String, _ bytes: Int64) -> some View {
    HStack { Text(title); Spacer(); Text(format(bytes)).foregroundStyle(Color.KinoPub.subtitle) }
  }

  private func format(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
  }

  private func recompute() {
    busy = true
    let store = AppContext.shared.hlsDownloadsStore
    let mp4URLs = (AppContext.shared.downloadedFilesDatabase.readData() ?? []).map { $0.localFileURL }
    Task.detached(priority: .utility) {
      let result = StorageUsage.compute(hlsStore: store, mp4URLs: mp4URLs)
      await MainActor.run { self.breakdown = result; self.busy = false }
    }
  }
}

/// Computed on-disk usage buckets. `total` is the whole app data container (Documents + Library + tmp).
private struct StorageUsage {
  let total: Int64
  let downloads: Int64
  let imageCache: Int64
  var other: Int64 { max(0, total - downloads - imageCache) }

  static func compute(hlsStore: HLSDownloadsStore, mp4URLs: [URL]) -> StorageUsage {
    let home = URL(fileURLWithPath: NSHomeDirectory())
    let containers = ["Documents", "Library", "tmp"].map { home.appendingPathComponent($0) }
    let total = containers.reduce(Int64(0)) { $0 + HLSDownloadsStore.directorySize(at: $1) }
    let mp4 = mp4URLs.reduce(Int64(0)) { acc, url in
      acc + ((try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0)
    }
    let downloads = hlsStore.totalDownloadedBytes() + mp4
    let imageCache = Int64(ImageCache.shared.diskUsageBytes())
    return StorageUsage(total: total, downloads: downloads, imageCache: imageCache)
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
