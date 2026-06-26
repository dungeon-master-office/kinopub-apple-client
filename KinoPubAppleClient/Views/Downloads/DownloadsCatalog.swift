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
  
  var cancellables = [AnyCancellable]()
  
  var isEmpty: Bool {
    downloadedItems.isEmpty && activeDownloads.isEmpty
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
    cancellables.removeAll()
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
  
  func toggle(download: Download<DownloadMeta>) {
    if download.state == .inProgress {
      download.pause()
    } else {
      download.resume()
    }
  }
}
