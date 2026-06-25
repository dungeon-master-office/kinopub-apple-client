//
//  HLSAssetDownloadManager.swift
//  KinoPubAppleClient
//
//  Downloads HLS streams (master .m3u8) for offline playback using
//  AVAssetDownloadURLSession + AVAggregateAssetDownloadTask so that ALL audio
//  tracks (озвучки) and subtitles are downloaded alongside the video and remain
//  switchable during offline playback.
//
//  IMPORTANT: AVAssetDownloadURLSession / AVAggregateAssetDownloadTask are
//  iOS/tvOS only — NOT available on macOS. All AVAssetDownload* usage is gated
//  behind `#if os(iOS)`. On macOS this type exists as a no-op so shared code
//  (AppContext, DownloadsCatalog, MediaItemModel) compiles unchanged; the macOS
//  download path continues to use the mp4 `DownloadManager`.
//

import Foundation
import Combine
import KinoPubBackend
import KinoPubLogging
import OSLog
import AVFoundation

/// Lightweight, UI-facing description of an in-flight HLS download.
public struct HLSActiveDownload: Identifiable, Equatable {
  public let id: String        // taskDescription key (meta id + video + season)
  public let meta: DownloadMeta
  public var progress: Float

  public init(id: String, meta: DownloadMeta, progress: Float) {
    self.id = id
    self.meta = meta
    self.progress = progress
  }
}

/// Stable key used as the task description so we can re-associate background
/// tasks with their metadata after an app relaunch.
enum HLSDownloadKey {
  static func make(for meta: DownloadMeta) -> String {
    "\(meta.id)|\(meta.metadata.video.map(String.init) ?? "-")|\(meta.metadata.season.map(String.init) ?? "-")"
  }
}

#if os(iOS)

public final class HLSAssetDownloadManager: NSObject, ObservableObject, AVAssetDownloadDelegate {

  /// In-flight downloads keyed by `HLSDownloadKey`.
  @Published public private(set) var activeDownloads: [HLSActiveDownload] = []

  private let store: HLSDownloadsStore
  /// Maximum desired resolution height (px) used to derive a bitrate cap, or nil
  /// for "best available" (adaptive). Injected from the app's StreamQuality
  /// setting where one exists.
  private let maxResolutionProvider: () -> Int?

  /// Notification hooks (mirrors the mp4 path). Optional so macOS / tests can omit.
  public var onDownloadFinished: ((DownloadMeta) -> Void)?
  public var onDownloadFailed: ((DownloadMeta) -> Void)?

  // Per-running-task state.
  private struct TaskContext {
    let meta: DownloadMeta
    let hlsURL: URL
    let retryCount: Int
    var downloadURL: URL?      // the .movpkg location handed to us by the delegate
  }
  private var contexts: [Int: TaskContext] = [:]   // keyed by task.taskIdentifier
  /// kino.pub rate-limits (HTTP 429) aggressive HLS downloads; we retry with backoff this many times.
  private let maxRetries = 5

  public init(store: HLSDownloadsStore,
              maxResolutionProvider: @escaping () -> Int? = { nil }) {
    self.store = store
    self.maxResolutionProvider = maxResolutionProvider
    super.init()
    _ = session // force lazy creation so background tasks are reattached
  }

  private lazy var session: AVAssetDownloadURLSession = {
    let config = URLSessionConfiguration.background(withIdentifier: "com.kinopub.hlsDownloadSession")
    return AVAssetDownloadURLSession(configuration: config,
                                     assetDownloadDelegate: self,
                                     delegateQueue: .main)
  }()

  // MARK: - Public API

  /// Starts (or no-ops if already running) an HLS download of `hlsURL` for `meta`.
  public func startDownload(meta: DownloadMeta, hlsURL: URL) {
    let key = HLSDownloadKey.make(for: meta)

    // Already downloading?
    if activeDownloads.contains(where: { $0.id == key }) {
      Logger.kit.debug("[HLS] download already active for key \(key)")
      return
    }
    // Already downloaded?
    if store.asset(forId: meta.id, video: meta.metadata.video, season: meta.metadata.season) != nil {
      Logger.kit.debug("[HLS] asset already downloaded for key \(key)")
      return
    }
    launch(meta: meta, hlsURL: hlsURL, retryCount: 0)
  }

  /// Builds and resumes an aggregate download. Attempts 0…maxRetries-2 grab every audio (озвучка) +
  /// subtitle track; the final attempt narrows to the preferred selection (video + default audio) so
  /// a heavily rate-limited title can still complete rather than failing outright.
  private func launch(meta: DownloadMeta, hlsURL: URL, retryCount: Int) {
    let key = HLSDownloadKey.make(for: meta)
    let asset = AVURLAsset(url: hlsURL)
    let narrow = retryCount >= maxRetries - 1

    var mediaSelections: [AVMediaSelection] = []
    if !narrow, let baseSelection = asset.preferredMediaSelection.mutableCopy() as? AVMutableMediaSelection {
      for characteristic in [AVMediaCharacteristic.audible, .legible] {
        guard let group = asset.mediaSelectionGroup(forMediaCharacteristic: characteristic) else { continue }
        for option in group.options {
          guard let selection = baseSelection.mutableCopy() as? AVMutableMediaSelection else { continue }
          selection.select(option, in: group)
          mediaSelections.append(selection)
        }
      }
    }
    // Always include the preferred selection (video + default tracks).
    mediaSelections.append(asset.preferredMediaSelection)

    var options: [String: Any] = [:]
    if let maxResolution = maxResolutionProvider() {
      let bitrate = max(800_000, (maxResolution / 360) * 2_000_000)
      options[AVAssetDownloadTaskMinimumRequiredMediaBitrateKey] = bitrate
    }

    guard let task = session.aggregateAssetDownloadTask(with: asset,
                                                        mediaSelections: mediaSelections,
                                                        assetTitle: meta.localizedTitle,
                                                        assetArtworkData: nil,
                                                        options: options.isEmpty ? nil : options) else {
      Logger.kit.error("[HLS] failed to create aggregate download task for key \(key)")
      activeDownloads.removeAll(where: { $0.id == key })
      onDownloadFailed?(meta)
      return
    }

    task.taskDescription = key
    contexts[task.taskIdentifier] = TaskContext(meta: meta, hlsURL: hlsURL, retryCount: retryCount)
    if let idx = activeDownloads.firstIndex(where: { $0.id == key }) {
      activeDownloads[idx].progress = 0   // keep the row visible across retries
    } else {
      activeDownloads.append(HLSActiveDownload(id: key, meta: meta, progress: 0))
    }
    task.resume()
    Logger.kit.debug("[HLS] started download for key \(key) (attempt \(retryCount + 1), narrow: \(narrow))")
  }

  /// Cancels an in-flight download for the given key.
  public func cancelDownload(key: String) {
    session.getAllTasks { [weak self] tasks in
      for task in tasks where task.taskDescription == key {
        task.cancel()
      }
      DispatchQueue.main.async {
        self?.activeDownloads.removeAll(where: { $0.id == key })
      }
    }
  }

  /// Reattaches any in-flight background tasks after a relaunch and rebuilds the
  /// `activeDownloads` list. Metadata is recovered from `taskDescription`.
  public func restorePendingDownloads() {
    session.getAllTasks { [weak self] tasks in
      guard let self else { return }
      var restored: [HLSActiveDownload] = []
      for task in tasks {
        guard let aggregate = task as? AVAggregateAssetDownloadTask,
              let key = aggregate.taskDescription else { continue }
        // We can recover the key but not the full DownloadMeta from the system,
        // so only re-list downloads we still hold context for (same process) or
        // fabricate a minimal placeholder otherwise.
        if let ctx = self.contexts[aggregate.taskIdentifier] {
          restored.append(HLSActiveDownload(id: key, meta: ctx.meta, progress: 0))
        }
      }
      if !restored.isEmpty {
        DispatchQueue.main.async {
          for item in restored where !self.activeDownloads.contains(where: { $0.id == item.id }) {
            self.activeDownloads.append(item)
          }
        }
      }
    }
  }

  // MARK: - AVAssetDownloadDelegate

  /// Gives us the local `.movpkg` location. Apple: persist the RELATIVE path and
  /// do not move the bundle.
  public func urlSession(_ session: URLSession,
                         aggregateAssetDownloadTask: AVAggregateAssetDownloadTask,
                         willDownloadTo location: URL) {
    Logger.kit.debug("[HLS] willDownloadTo \(location.relativePath)")
    contexts[aggregateAssetDownloadTask.taskIdentifier]?.downloadURL = location
  }

  /// Progress for the currently-downloading media selection.
  public func urlSession(_ session: URLSession,
                         aggregateAssetDownloadTask: AVAggregateAssetDownloadTask,
                         didLoad timeRange: CMTimeRange,
                         totalTimeRangesLoaded loadedTimeRanges: [NSValue],
                         timeRangeExpectedToLoad: CMTimeRange,
                         for mediaSelection: AVMediaSelection) {
    let id = aggregateAssetDownloadTask.taskIdentifier
    guard contexts[id] != nil else { return }

    var loadedSeconds = 0.0
    for value in loadedTimeRanges {
      loadedSeconds += CMTimeGetSeconds(value.timeRangeValue.duration)
    }
    let expected = CMTimeGetSeconds(timeRangeExpectedToLoad.duration)
    guard expected > 0 else { return }
    let progress = Float(min(1.0, loadedSeconds / expected))

    if let key = aggregateAssetDownloadTask.taskDescription,
       let idx = activeDownloads.firstIndex(where: { $0.id == key }) {
      activeDownloads[idx].progress = progress
    }
  }

  /// Completion. On success persist a record (relative path); on failure notify.
  public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    let id = task.taskIdentifier
    guard let ctx = contexts[id] else { return }
    let key = task.taskDescription ?? HLSDownloadKey.make(for: ctx.meta)
    contexts[id] = nil

    if let error = error as NSError? {
      // Cancellation isn't a "failure" worth notifying about.
      if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
        Logger.kit.debug("[HLS] download cancelled for key \(key)")
        activeDownloads.removeAll(where: { $0.id == key })
        return
      }
      // kino.pub rate-limits aggressive HLS downloads (HTTP 429 → CoreMedia -16845). These are
      // transient: wait with exponential backoff and resume — AVFoundation keeps the partial
      // .movpkg, and the final retry narrows to the default track so it can finish.
      let rateLimited = error.code == -16845 || error.localizedDescription.contains("429")
      if rateLimited, ctx.retryCount < maxRetries {
        let delays: [UInt64] = [5, 15, 30, 60, 120]
        let seconds = delays[min(ctx.retryCount, delays.count - 1)]
        let next = ctx.retryCount + 1
        Logger.kit.error("[HLS] rate-limited (429) for key \(key); retry \(next + 1) in \(seconds)s")
        Task { @MainActor [weak self] in
          try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
          self?.launch(meta: ctx.meta, hlsURL: ctx.hlsURL, retryCount: next)
        }
        return  // keep the active row visible while we wait
      }
      Logger.kit.error("[HLS] download failed for key \(key): \(error)")
      activeDownloads.removeAll(where: { $0.id == key })
      onDownloadFailed?(ctx.meta)
      return
    }

    activeDownloads.removeAll(where: { $0.id == key })
    guard let location = ctx.downloadURL else {
      Logger.kit.error("[HLS] download finished but no location for key \(key)")
      onDownloadFailed?(ctx.meta)
      return
    }

    let asset = HLSDownloadedAsset(meta: ctx.meta,
                                   relativePath: location.relativePath,
                                   downloadDate: Date())
    store.save(asset)
    Logger.kit.info("[HLS] download finished for key \(key)")
    onDownloadFinished?(ctx.meta)
  }
}

#else

// macOS (and any non-iOS platform): no-op shim with the same public surface so
// shared code compiles. The mp4 DownloadManager handles downloads on macOS.
public final class HLSAssetDownloadManager: ObservableObject {

  @Published public private(set) var activeDownloads: [HLSActiveDownload] = []

  public var onDownloadFinished: ((DownloadMeta) -> Void)?
  public var onDownloadFailed: ((DownloadMeta) -> Void)?

  public init(store: HLSDownloadsStore,
              maxResolutionProvider: @escaping () -> Int? = { nil }) {}

  public func startDownload(meta: DownloadMeta, hlsURL: URL) {
    Logger.kit.debug("[HLS] HLS downloads are not supported on this platform; ignoring.")
  }

  public func cancelDownload(key: String) {}

  public func restorePendingDownloads() {}
}

#endif
