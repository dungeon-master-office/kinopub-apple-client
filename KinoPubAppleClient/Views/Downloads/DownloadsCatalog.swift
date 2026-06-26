//
//  DownloadsCatalog.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 8.08.2023.
//

import Foundation
import KinoPubBackend
import KinoPubLogging
import KinoPubKit
import OSLog
import Combine

@MainActor
class DownloadsCatalog: ObservableObject {
  
  private var downloadsDatabase: DownloadedFilesDatabase<DownloadMeta>
  private var downloadManager: DownloadManager<DownloadMeta>
  
  @Published public var downloadedItems: [DownloadedFileInfo<DownloadMeta>] = []
  @Published public var activeDownloads: [Download<DownloadMeta>] = []
  /// Offline HLS downloads (in-progress + completed), accessed via AppContext.shared.
  @Published public var hlsActive: [HLSActiveDownload] = []
  @Published public var hlsCompleted: [HLSDownloadedAsset] = []
  /// HLS downloads interrupted by a force-quit (can't resume) — offered for re-download.
  @Published public var hlsInterrupted: [HLSInterruptedDownload] = []
  /// Total on-disk size of all completed downloads (HLS .movpkg + mp4), for the storage footer.
  @Published public var totalBytes: Int64 = 0
  /// Last HLS download failure reason (mirrored from the manager) so the screen can show it.
  @Published public var downloadError: String?

  private var hlsManager: HLSAssetDownloadManager { AppContext.shared.hlsDownloadManager }
  private var hlsStore: HLSDownloadsStore { AppContext.shared.hlsDownloadsStore }

  var cancellables = [AnyCancellable]()

  var isEmpty: Bool {
    downloadedItems.isEmpty && activeDownloads.isEmpty && hlsActive.isEmpty
      && hlsCompleted.isEmpty && hlsInterrupted.isEmpty
  }
  
  init(downloadsDatabase: DownloadedFilesDatabase<DownloadMeta>, downloadManager: DownloadManager<DownloadMeta>) {
    self.downloadsDatabase = downloadsDatabase
    self.downloadManager = downloadManager
  }
  
  func refresh() {
    // Files now live in the app's Documents folder (visible in the Files app), so the user can delete
    // them out-of-band. Drop any entries whose file is gone and clean the DB so the list stays honest.
    let stored = downloadsDatabase.readData() ?? []
    var present: [DownloadedFileInfo<DownloadMeta>] = []
    for info in stored {
      if FileManager.default.fileExists(atPath: info.localFileURL.path) {
        present.append(info)
      } else {
        downloadsDatabase.remove(fileInfo: info)
      }
    }
    self.downloadedItems = present
    self.activeDownloads = downloadManager.activeDownloads.map({ $0.value })
    // HLS: completed assets (reconciled against disk) + in-flight downloads.
    self.hlsCompleted = hlsStore.reconcile()
    self.hlsActive = hlsManager.activeDownloads
    self.hlsInterrupted = Self.interruptedExcludingCompleted(hlsManager.interrupted, completed: self.hlsCompleted)
    cancellables.removeAll()
    // Republish when the HLS manager's downloads change (progress / completion). objectWillChange
    // fires before the change, so read on the next main-queue tick to pick up new values.
    hlsManager.objectWillChange
      .receive(on: DispatchQueue.main)
      .sink(receiveValue: { [weak self] in
        guard let self else { return }
        self.hlsActive = self.hlsManager.activeDownloads
        self.hlsCompleted = self.hlsStore.readData()
        self.hlsInterrupted = Self.interruptedExcludingCompleted(self.hlsManager.interrupted, completed: self.hlsCompleted)
        self.downloadError = self.hlsManager.lastError
      })
      .store(in: &cancellables)
    recomputeTotalSize()
    self.activeDownloads.forEach({
      // Re-deliver on the main queue asynchronously: a progress tick must not republish *during*
      // a SwiftUI view update (that traps with "Publishing changes from within view updates").
      let c = $0.objectWillChange
        .receive(on: DispatchQueue.main)
        .sink(receiveValue: { [weak self] in self?.objectWillChange.send() })
      self.cancellables.append(c)
    })
    
  }
  
  func deleteDownloadedItem(at indexSet: IndexSet) {
    for index in indexSet {
      downloadsDatabase.remove(fileInfo: downloadedItems[index])
    }
    // Mutate the published array too, so `isEmpty` flips and the placeholder shows once all are gone.
    downloadedItems.remove(atOffsets: indexSet)
  }

  func deleteActiveDownload(at indexSet: IndexSet) {
    for index in indexSet {
      downloadManager.removeDownload(for: activeDownloads[index].url)
    }
    activeDownloads.remove(atOffsets: indexSet)
  }

  func cancelHLSDownload(at indexSet: IndexSet) {
    for index in indexSet {
      hlsManager.cancelDownload(key: hlsActive[index].id)
    }
    hlsActive.remove(atOffsets: indexSet)
  }

  func deleteHLSCompleted(at indexSet: IndexSet) {
    for index in indexSet {
      hlsStore.remove(hlsCompleted[index])
    }
    hlsCompleted.remove(atOffsets: indexSet)
  }

  /// Sum the on-disk size of every completed download (HLS bundles + mp4 files) off the main thread.
  private func recomputeTotalSize() {
    let mp4URLs = downloadedItems.map { $0.localFileURL }
    let store = hlsStore
    Task.detached(priority: .utility) {
      let hls = store.totalDownloadedBytes()
      let mp4 = mp4URLs.reduce(Int64(0)) { acc, url in
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return acc + ((attrs?[.size] as? Int64) ?? 0)
      }
      await MainActor.run { [weak self] in self?.totalBytes = hls + mp4 }
    }
  }

  /// A completed download must never also appear as "interrupted" (e.g. a stale pending entry whose
  /// asset is already on disk) — drop any interrupted item that matches a completed one.
  private static func interruptedExcludingCompleted(_ interrupted: [HLSInterruptedDownload],
                                                    completed: [HLSDownloadedAsset]) -> [HLSInterruptedDownload] {
    interrupted.filter { item in
      !completed.contains(where: { HLSDownloadsStore.sameItem($0.meta, item.meta) })
    }
  }

  /// Re-download an interrupted HLS item (its background task didn't survive a force-quit).
  func retryHLSInterrupted(_ item: HLSInterruptedDownload) {
    hlsManager.retryInterrupted(item.id)
    hlsInterrupted.removeAll { $0.id == item.id }
  }

  func dismissHLSInterrupted(at indexSet: IndexSet) {
    for index in indexSet {
      hlsManager.dismissInterrupted(hlsInterrupted[index].id)
    }
    hlsInterrupted.remove(atOffsets: indexSet)
  }
  
  func toggle(download: Download<DownloadMeta>) {
    if download.state == .inProgress {
      download.pause()
    } else {
      download.resume()
    }
  }
}
