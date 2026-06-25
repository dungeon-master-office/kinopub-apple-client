//
//  PlayerManager.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 3.08.2023.
//

import Foundation
import SwiftUI
import Combine
import KinoPubBackend
import KinoPubKit
import AVFoundation
import KinoPubLogging
import OSLog

enum WatchMode {
  case media
  case trailer
}

class PlayerManager: ObservableObject {
  
  @Published var isPlaying: Bool = false
  @Published var watchMark: WatchData?
  @Published var continueTime: TimeInterval?
  
  lazy var player: AVPlayer = {
    guard let fileURL else { return AVPlayer() }
    let item = AVPlayerItem(url: fileURL)
    // Cap the adaptive HLS stream to the user's chosen quality. kino.pub serves one master
    // playlist with every rendition, so this is the lever that limits quality — `.auto` leaves
    // it untouched. Harmless for local/trailer playback (no effect on non-HLS items).
    if watchMode == .media, let maxResolution = StreamQuality.current.maxResolution {
      item.preferredMaximumResolution = maxResolution
    }
    // Surface the title (and season/episode) in the native player UI (iOS/tvOS only).
    #if !os(macOS)
    item.externalMetadata = externalMetadata()
    #endif
    return AVPlayer(playerItem: item)
  }()

  #if !os(macOS)
  private func externalMetadata() -> [AVMetadataItem] {
    var items: [AVMetadataItem] = []
    // For a trailer, make it explicit in the player's title.
    var title = playItem.playerTitle
    if watchMode == .trailer, !title.isEmpty {
      title += " — \("Trailer".localized)"
    }
    if !title.isEmpty {
      let titleItem = AVMutableMetadataItem()
      titleItem.identifier = .commonIdentifierTitle
      titleItem.value = title as NSString
      titleItem.extendedLanguageTag = "und"
      items.append(titleItem)
    }
    if let subtitle = playItem.playerSubtitle, !subtitle.isEmpty {
      let subtitleItem = AVMutableMetadataItem()
      subtitleItem.identifier = .iTunesMetadataTrackSubTitle
      subtitleItem.value = subtitle as NSString
      subtitleItem.extendedLanguageTag = "und"
      items.append(subtitleItem)
    }
    return items
  }
  #endif
  private var playerTimeObserver: PlayerTimeObserver?
  private var playItem: any PlayableItem
  private var watchMode: WatchMode
  private var downloadedFilesDatabase: DownloadedFilesDatabase<DownloadMeta>
  private var rateObservation: NSKeyValueObservation?
  private var seekObservation: NSKeyValueObservation?
  private var actionsService: UserActionsService
  
  private var fileURL: URL? {
    switch watchMode {
    case .media:
      let downloadedFiles = downloadedFilesDatabase.readData() ?? []
      let sameItem = downloadedFiles.filter { $0.metadata.id == playItem.id }
      // For a series there can be several downloads under the same (series) id, plus stale rows whose
      // file was deleted. Pick the row whose source URL matches THIS item's files (the right episode),
      // then any same-item row — but only when the file is actually present on disk. Otherwise fall
      // through to streaming instead of handing AVPlayer a missing file (the "crossed-out play" icon).
      let playURLs = Set(playItem.files.map { $0.url.http })
      let chosen = sameItem.first(where: { playURLs.contains($0.originalURL.absoluteString) }) ?? sameItem.first
      if let chosen, FileManager.default.fileExists(atPath: chosen.localFileURL.path) {
        return chosen.localFileURL
      }
      let urlString = BestVideoQualityFinder.findBestURL(for: playItem.files)
      guard !urlString.isEmpty, let url = URL(string: urlString) else { return nil }
      return url
    case .trailer:
      guard let urlString = playItem.trailer?.url, !urlString.isEmpty,
            let url = URL(string: urlString) else { return nil }
      return url
    }
  }
  
  init(playItem: any PlayableItem,
       watchMode: WatchMode,
       downloadedFilesDatabase: DownloadedFilesDatabase<DownloadMeta>,
       actionsService: UserActionsService) {
    self.playItem = playItem
    self.watchMode = watchMode
    self.actionsService = actionsService
    self.downloadedFilesDatabase = downloadedFilesDatabase
    rateObservation = player.observe(\.rate, options: [.new]) { [weak self] player, _ in
      DispatchQueue.main.async {
        self?.isPlaying = player.rate > 0
      }
    }
    
    playerTimeObserver = PlayerTimeObserver(player: player, period: 10.0, timeUpdateHandler: { [weak self] time in
      self?.saveWatchMark(time: time)
    })
  }
  
  // MARK: - Watch marks
  
  func saveWatchMark(time: TimeInterval) {
    // Persist a local resume point so "Continue Watching" reflects what the user actually
    // started, independent of the backend (skips live/trailers via the non-finite duration).
    if watchMode == .media {
      let duration = player.currentItem?.duration.seconds ?? 0
      AppContext.shared.localProgressStore.recordProgress(mediaId: playItem.metadata.id,
                                                          position: time,
                                                          duration: duration,
                                                          season: playItem.metadata.season,
                                                          episode: playItem.metadata.video)
    }

    Task.detached(priority: .utility) { [weak self] in
      guard let self else { return }
      do {
        try await self.actionsService.markWatch(id: self.playItem.metadata.id,
                                                time: Int(time), video: self.playItem.metadata.video,
                                                season: self.playItem.metadata.season)
      } catch {
        Logger.app.error("Failed to save watch mark: \(error)")
      }
    }
  }
  
  func fetchWatchMark() async {
    // Only media has a resume point (live/trailers don't).
    guard watchMode == .media else { return }

    var remoteContinueTime: TimeInterval = 0
    do {
      watchMark = try await actionsService.fetchWatchMark(id: playItem.metadata.id, video: playItem.metadata.video, season: playItem.metadata.season)
      if let watchMark {
        remoteContinueTime = watchMark.item.videos?.first?.time ?? watchMark.item.seasons?.first?.episodes.first?.time ?? 0
      }
    } catch {
      Logger.app.error("Failed to fetch watch mark: \(error)")
    }

    // Fall back to the local resume point: a movie/episode watched in-app records its position
    // locally on every tick, so it resumes even when the server mark lags or the fetch fails.
    let localContinueTime = AppContext.shared.localProgressStore.allEntries().first {
      $0.id == playItem.metadata.id
        && $0.season == playItem.metadata.season
        && $0.episode == playItem.metadata.video
    }?.position ?? 0

    let best = max(remoteContinueTime, localContinueTime)
    continueTime = best > 0 ? best : nil
  }
  
  // MARK: - Continue watching
  
  func seekToContinueWatching() {
    guard let continueTime else {
      return
    }
    let seekTime = CMTime(seconds: continueTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    self.continueTime = nil

    // Seek now if the item is ready; otherwise wait for it to become ready and seek once. Seeking
    // a not-yet-ready item is silently dropped, which is why resume sometimes "played from start".
    if player.currentItem?.status == .readyToPlay {
      player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero)
    } else {
      seekObservation = player.currentItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
        guard item.status == .readyToPlay else { return }
        self?.player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero)
        self?.seekObservation?.invalidate()
        self?.seekObservation = nil
      }
    }
  }
  
  func cancelContinueWatching() {
    self.continueTime = nil
  }
  
}
