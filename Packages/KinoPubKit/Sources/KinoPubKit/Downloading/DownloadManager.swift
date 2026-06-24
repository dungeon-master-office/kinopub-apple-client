//
//  DownloadManager.swift
//
//
//  Created by Kirill Kunst on 22.07.2023.
//

import Foundation
import OSLog
import KinoPubLogging

public protocol DownloadManaging {
  associatedtype Meta: Codable & Equatable
  
  var session: URLSession { get }
  func startDownload(url: URL, withMetadata metadata: Meta) -> Download<Meta>
  func removeDownload(for url: URL)
  func completeDownload(_ url: URL)
}

public class DownloadManager<Meta: Codable & Equatable>: NSObject, URLSessionDownloadDelegate, DownloadManaging {
  @Published public var activeDownloads: [URL: Download<Meta>] = [:]
  private var fileSaver: FileSaving
  private var database: DownloadedFilesDatabase<Meta>
  private var controlDatabase: DownloadsControlDatabase<Meta>?

  /// Completion handler stored by the app delegate when the system relaunches the app to finish
  /// background URLSession events. Invoked once the session reports it finished delivering events.
  public var backgroundCompletionHandler: (() -> Void)?

  public init(fileSaver: FileSaving,
              database: DownloadedFilesDatabase<Meta>,
              controlDatabase: DownloadsControlDatabase<Meta>? = nil) {
    self.fileSaver = fileSaver
    self.database = database
    self.controlDatabase = controlDatabase
    super.init()
    restoreDownloads()
  }

  lazy public var session: URLSession = {
    let identifier = "com.kinopub.backgroundDownloadSession"
    let config = URLSessionConfiguration.background(withIdentifier: identifier)
    return URLSession(configuration: config, delegate: self, delegateQueue: nil)
  }()

  public func startDownload(url: URL, withMetadata metadata: Meta) -> Download<Meta> {
    let download = Download(url: url, metadata: metadata, manager: self)
    observeStateChanges(of: download)
    download.resume()
    activeDownloads[url] = download
    persist(download)
    return download
  }

  public func removeDownload(for url: URL) {
    guard let download = activeDownloads[url] else {
      return
    }

    download.pause()
    activeDownloads[url] = nil
    controlDatabase?.remove(url: url)
  }

  public func completeDownload(_ url: URL) {
    activeDownloads[url] = nil
    controlDatabase?.remove(url: url)
  }

  /// Rebuilds `activeDownloads` from persisted control info as paused `Download` objects so the user
  /// can resume them after relaunching the app. Resume data may be `nil`, which is handled gracefully.
  public func restoreDownloads() {
    guard let stored = controlDatabase?.readData(), !stored.isEmpty else { return }
    for info in stored {
      let download = Download(url: info.originalURL,
                              metadata: info.metadata,
                              manager: self,
                              resumeData: info.resumeData,
                              progress: info.progress)
      observeStateChanges(of: download)
      activeDownloads[info.originalURL] = download
      Logger.kit.debug("[DOWNLOAD] restored paused download for: \(info.originalURL)")
    }
  }

  // MARK: - Persistence helpers

  private func observeStateChanges(of download: Download<Meta>) {
    download.onStateChange = { [weak self] download in
      self?.persist(download)
    }
  }

  private func persist(_ download: Download<Meta>) {
    let info = DownloadControlInfo(originalURL: download.url,
                                   resumeData: download.resumeData,
                                   progress: download.progress,
                                   metadata: download.metadata)
    controlDatabase?.save(controlInfo: info)
  }

  // MARK: URLSessionDownloadDelegate methods

  public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    guard let sourceURL = downloadTask.originalRequest?.url, let download = activeDownloads[sourceURL] else { return }
    Logger.kit.debug("[DOWNLOAD] Download finished: \(location)")

    let destinationURL = fileSaver.getDocumentsDirectoryURL(forFilename: sourceURL.lastPathComponent)

    do {
      try fileSaver.saveFile(from: location, to: destinationURL)
      Logger.kit.info("[DOWNLOAD] File: \(location) moved to documents folder")

      let fileInfo = DownloadedFileInfo(originalURL: sourceURL, localFilename: sourceURL.lastPathComponent, downloadDate: Date(), metadata: download.metadata)
      database.save(fileInfo: fileInfo)
    } catch {
      Logger.kit.error("[DOWNLOAD] Error during moving file: \(error)")
    }

    completeDownload(sourceURL)
  }

  public func urlSession(_ session: URLSession,
                         downloadTask: URLSessionDownloadTask,
                         didWriteData bytesWritten: Int64,
                         totalBytesWritten: Int64,
                         totalBytesExpectedToWrite: Int64) {
    if totalBytesExpectedToWrite > 0, let download = activeDownloads[downloadTask.originalRequest?.url ?? URL(fileURLWithPath: "")] {
      let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
      Logger.kit.debug("[DOWNLOAD] progress for download: \(download.url), value: \(progress)")
      // Persist a progress checkpoint (throttled to whole-percent steps) so a partially
      // completed download survives a relaunch without writing the plist on every callback.
      let shouldCheckpoint = Int(progress * 100) != Int(download.progress * 100)
      DispatchQueue.main.async {
        download.updateProgress(progress)
        if shouldCheckpoint {
          self.persist(download)
        }
      }
    }
  }

  public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    if let error = error, let url = task.originalRequest?.url {
      Logger.kit.debug("[DOWNLOAD] Download error for \(url): \(error)")
      completeDownload(url)
    }
  }

  public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    Logger.kit.debug("[DOWNLOAD] background session finished events")
    DispatchQueue.main.async {
      let handler = self.backgroundCompletionHandler
      self.backgroundCompletionHandler = nil
      handler?()
    }
  }
}
