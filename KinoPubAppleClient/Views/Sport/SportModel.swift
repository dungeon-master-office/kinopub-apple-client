//
//  SportModel.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 24.06.2026.
//

import Foundation
import KinoPubBackend
import OSLog
import KinoPubLogging
import Combine

@MainActor
class SportModel: ObservableObject {

  private var authState: AuthState
  private var errorHandler: ErrorHandler
  private var contentService: VideoContentService
  private var epgService: EPGService
  private var bag = Set<AnyCancellable>()

  @Published public var channels: [TVChannel] = []
  @Published public var isLoading: Bool = true
  /// Channel shown in the always-on-top player. Drives both the player and the list selection.
  @Published public var selectedChannel: TVChannel?
  /// Programmes per channel (`TVChannel.id`), sorted by start time. Missing key == no EPG match.
  @Published public private(set) var epgByChannel: [Int: [EPGProgram]] = [:]
  /// True while the programme guide is being fetched — rows show "loading" instead of "no programme".
  @Published public private(set) var isLoadingGuide: Bool = false
  /// When the guide last finished loading (drives the "updated at HH:mm" caption).
  @Published public private(set) var guideUpdatedAt: Date?

  init(itemsService: VideoContentService,
       epgService: EPGService,
       authState: AuthState,
       errorHandler: ErrorHandler) {
    self.contentService = itemsService
    self.epgService = epgService
    self.authState = authState
    self.errorHandler = errorHandler
    // Load on creation, not via the view's `.task` (unreliable in a compact split view / nested stack).
    Task { await fetchChannels() }
  }

  func fetchChannels(forceGuideRefresh: Bool = false) async {
    guard authState.userState == .authorized else {
      subscribeForAuth()
      return
    }

    isLoading = true
    do {
      let fetched = try await contentService.fetchTVChannels()
      channels = fetched
      if selectedChannel == nil { selectedChannel = fetched.first }
    } catch {
      Logger.app.debug("fetch tv channels error: \(error)")
      errorHandler.setError(error)
    }
    isLoading = false
    await loadGuide(forceRefresh: forceGuideRefresh)
  }

  /// Loads the programme guide. Non-fatal: channels still play if the EPG feed is unavailable.
  /// Publishes `isLoadingGuide` so the UI can show progress instead of a misleading "no programme".
  func loadGuide(forceRefresh: Bool) async {
    guard !channels.isEmpty else { return }
    isLoadingGuide = true
    defer { isLoadingGuide = false }
    do {
      epgByChannel = try await epgService.fetchGuide(for: channels, forceRefresh: forceRefresh)
      // Real download time (from the cache), not the moment of this cache hit.
      guideUpdatedAt = await epgService.lastUpdated() ?? Date()
    } catch {
      Logger.app.debug("fetch epg error: \(error)")
    }
  }

  @Sendable @MainActor
  func refresh() async {
    errorHandler.reset()
    await fetchChannels(forceGuideRefresh: true)
  }

  // MARK: - EPG lookups (pure; caller passes `now` from a ticking clock)

  /// The programme currently on air for `channel`.
  func currentProgram(for channel: TVChannel, at now: Date) -> EPGProgram? {
    epgByChannel[channel.id]?.first { $0.isLive(at: now) }
  }

  /// The next programme to start after `now`.
  func nextProgram(for channel: TVChannel, at now: Date) -> EPGProgram? {
    epgByChannel[channel.id]?.first { $0.start > now }
  }

  /// Up to `limit` programmes that have not finished yet (current first, then upcoming).
  func upcoming(for channel: TVChannel, at now: Date, limit: Int = 8) -> [EPGProgram] {
    guard let programs = epgByChannel[channel.id] else { return [] }
    return Array(programs.filter { $0.stop > now }.prefix(limit))
  }

  /// Whether any EPG data was matched at all (used to decide whether to show programme UI).
  var hasGuide: Bool { !epgByChannel.isEmpty }

  private func subscribeForAuth() {
    authState.$userState.filter({ $0 == .authorized }).first().sink { [weak self] _ in
      Task {
        await self?.refresh()
      }
    }.store(in: &bag)
  }

}
