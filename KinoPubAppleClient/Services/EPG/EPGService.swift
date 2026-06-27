//
//  EPGService.swift
//  KinoPubAppleClient
//
//  Electronic Programme Guide for live TV channels, sourced from an external XMLTV feed
//  and matched to kino.pub channels by name.
//

import Foundation
import KinoPubBackend

protocol EPGService {
  /// Programmes for each given channel, keyed by `TVChannel.id`. Channels with no EPG match are
  /// simply absent from the result. Implementations may serve cached data unless `forceRefresh` is set.
  func fetchGuide(for channels: [TVChannel], forceRefresh: Bool) async throws -> [Int: [EPGProgram]]

  /// When the currently-served guide was actually downloaded (newest across sources) — the real
  /// download time, not the moment of a cache hit, so the UI can show an honest "updated" timestamp.
  func lastUpdated() async -> Date?

  /// Drops all cached guide data (on-disk files + in-memory), so the next fetch re-downloads.
  func clearCache() async
}

protocol EPGServiceProvider {
  var epgService: EPGService { get set }
}

/// No-op guide for previews and tests (channels still list/play, just without programme info).
struct EPGServiceMock: EPGService {
  var stub: [Int: [EPGProgram]] = [:]
  func fetchGuide(for channels: [TVChannel], forceRefresh: Bool) async throws -> [Int: [EPGProgram]] {
    stub
  }
  func lastUpdated() async -> Date? { nil }
  func clearCache() async {}
}
