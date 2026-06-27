//
//  EPGServiceImpl.swift
//  KinoPubAppleClient
//
//  Downloads one or more XMLTV feeds (configured in EPGSources.json), stream-parses each (SAX, low
//  memory), keeps only the programmes around "now" for channels that match our kino.pub channels,
//  and caches each source to disk so we re-download at most a few times a day.
//
//  Sources are tried in order and merged per channel: the first source that has programmes for a
//  channel wins (iptv.online covers the Russian line-up; the iptv-epg.org UK feed fills Sky / TNT /
//  Premier). Matching is two-tier per source: an explicit override map (kino.pub title -> feed
//  channel id) is consulted first, then automatic normalized-name matching as a fallback. Overrides
//  exist because many kino.pub names differ from the feeds (e.g. "МАТЧ! ТВ" -> "Матч!", "TNT Sport 1"
//  -> "BT Sport 1 HD", "Sky Football" -> "SkySportsFootball.uk").
//

import Foundation
import KinoPubBackend
import OSLog
import KinoPubLogging

actor EPGServiceImpl: EPGService {

  /// Programme window kept around `now` — bounds both memory while parsing and the on-disk cache.
  private static let pastWindow: TimeInterval = 3 * 3600
  private static let futureWindow: TimeInterval = 48 * 3600

  private struct SourceConfig: Decodable {
    let id: String
    let url: String
    let cacheHours: Double
    let map: [String: String]
  }
  private struct SourcesFile: Decodable { let sources: [SourceConfig] }

  private let session: URLSession
  private let cachesDir: URL
  private lazy var sources: [SourceConfig] = Self.loadSources()
  private var memoryCache: [String: CachedGuide] = [:]   // keyed by source id

  init(session: URLSession = .shared) {
    self.session = session
    self.cachesDir = Self.cacheDirectory
  }

  // MARK: - Cache location / size / clearing (used by the Storage screen)

  /// Directory holding the per-source guide caches.
  static var cacheDirectory: URL {
    FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
      ?? FileManager.default.temporaryDirectory
  }

  /// All on-disk guide cache files (one `epg-cache-<source>.json` per source).
  static func cacheFileURLs() -> [URL] {
    let files = (try? FileManager.default.contentsOfDirectory(at: cacheDirectory,
                                                              includingPropertiesForKeys: [.fileSizeKey])) ?? []
    return files.filter { $0.lastPathComponent.hasPrefix("epg-cache-") && $0.pathExtension == "json" }
  }

  /// Total bytes used by the guide caches on disk.
  static func diskUsageBytes() -> Int64 {
    cacheFileURLs().reduce(Int64(0)) { acc, url in
      acc + Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
    }
  }

  /// Drops every cached guide (disk + memory) so the next fetch re-downloads.
  func clearCache() {
    for url in Self.cacheFileURLs() { try? FileManager.default.removeItem(at: url) }
    memoryCache.removeAll()
  }

  /// Newest real download time across the source caches (memory first, falling back to disk), so the
  /// UI shows when the guide was actually fetched rather than when it was last read from cache.
  func lastUpdated() -> Date? {
    var newest: Date? = memoryCache.values.map { $0.fetchedAt }.max()
    if newest == nil {
      for url in Self.cacheFileURLs() {
        if let data = try? Data(contentsOf: url),
           let cached = try? JSONDecoder.epg.decode(CachedGuide.self, from: data) {
          if newest == nil || cached.fetchedAt > newest! { newest = cached.fetchedAt }
        }
      }
    }
    return newest
  }

  func fetchGuide(for channels: [TVChannel], forceRefresh: Bool) async throws -> [Int: [EPGProgram]] {
    var merged: [Int: [EPGProgram]] = [:]
    // Sources are ordered by preference; the first one with data for a channel wins.
    for source in sources {
      guard let programs = await programmes(for: source, channels: channels, forceRefresh: forceRefresh) else { continue }
      for (id, list) in programs where merged[id] == nil && !list.isEmpty {
        merged[id] = list
      }
    }
    return merged
  }

  /// Programmes for one source. Serves a fresh cache when available; on download/parse failure it
  /// falls back to a stale cache (better an old guide than none) and never throws — a dead source
  /// just contributes nothing to the merge.
  private func programmes(for source: SourceConfig, channels: [TVChannel], forceRefresh: Bool) async -> [Int: [EPGProgram]]? {
    let cacheURL = cachesDir.appendingPathComponent("epg-cache-\(Self.safeName(source.id)).json")
    let ttl = source.cacheHours * 3600

    if !forceRefresh, let cached = loadCache(cacheURL, sourceID: source.id),
       Date().timeIntervalSince(cached.fetchedAt) < ttl {
      return cached.programs
    }
    guard let url = URL(string: source.url) else { return nil }

    do {
      var request = URLRequest(url: url)
      request.timeoutInterval = 120
      let (tempURL, response) = try await session.download(for: request)
      defer { try? FileManager.default.removeItem(at: tempURL) }

      if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
        return loadCache(cacheURL, sourceID: source.id)?.programs
      }

      let now = Date()
      let programs = try parse(fileURL: tempURL,
                               channels: channels,
                               overrides: source.map,
                               pastCutoff: now.addingTimeInterval(-Self.pastWindow),
                               futureCutoff: now.addingTimeInterval(Self.futureWindow))
      saveCache(CachedGuide(fetchedAt: now, programs: programs), to: cacheURL, sourceID: source.id)
      Logger.app.debug("epg[\(source.id)]: matched \(programs.count) channels")
      return programs
    } catch {
      Logger.app.debug("epg[\(source.id)] error: \(error)")
      return loadCache(cacheURL, sourceID: source.id)?.programs   // stale-on-failure
    }
  }

  // MARK: - Parsing

  private func parse(fileURL: URL,
                     channels: [TVChannel],
                     overrides: [String: String],
                     pastCutoff: Date,
                     futureCutoff: Date) throws -> [Int: [EPGProgram]] {
    guard let stream = InputStream(url: fileURL) else { throw URLError(.cannotOpenFile) }
    let parser = XMLParser(stream: stream)
    let delegate = EPGParserDelegate(channels: channels,
                                     overrides: overrides,
                                     pastCutoff: pastCutoff,
                                     futureCutoff: futureCutoff)
    parser.delegate = delegate
    guard parser.parse() else {
      throw parser.parserError ?? URLError(.cannotParseResponse)
    }
    // Per-channel chronological order (defensive: a channel may match more than one feed entry).
    return delegate.programs.mapValues { $0.sorted { $0.start < $1.start } }
  }

  // MARK: - Source config

  private static func loadSources() -> [SourceConfig] {
    guard let url = Bundle.main.url(forResource: "EPGSources", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let file = try? JSONDecoder().decode(SourcesFile.self, from: data) else {
      // Fallback so the feature still works if the resource is missing.
      return [SourceConfig(id: "iptv.online",
                           url: "https://iptv.online/epg/epg-lite.xml",
                           cacheHours: 6,
                           map: [:])]
    }
    return file.sources
  }

  private static func safeName(_ id: String) -> String {
    String(id.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : "-" })
  }

  // MARK: - Cache

  private struct CachedGuide: Codable {
    let fetchedAt: Date
    let programs: [Int: [EPGProgram]]
  }

  private func loadCache(_ cacheURL: URL, sourceID: String) -> CachedGuide? {
    if let cached = memoryCache[sourceID] { return cached }
    guard let data = try? Data(contentsOf: cacheURL),
          let cached = try? JSONDecoder.epg.decode(CachedGuide.self, from: data) else { return nil }
    memoryCache[sourceID] = cached
    return cached
  }

  private func saveCache(_ guide: CachedGuide, to cacheURL: URL, sourceID: String) {
    memoryCache[sourceID] = guide
    if let data = try? JSONEncoder.epg.encode(guide) {
      try? data.write(to: cacheURL, options: .atomic)
    }
  }
}

private extension JSONEncoder {
  static let epg: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .secondsSince1970
    return encoder
  }()
}

private extension JSONDecoder {
  static let epg: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    return decoder
  }()
}

// MARK: - SAX delegate

/// Streams the XMLTV document: records `<channel>` definitions, then keeps only the `<programme>`
/// entries that (a) belong to a channel matching one of ours and (b) fall inside the time window.
private final class EPGParserDelegate: NSObject, XMLParserDelegate {

  private(set) var programs: [Int: [EPGProgram]] = [:]

  private let pastCutoff: Date
  private let futureCutoff: Date

  private let channels: [TVChannel]
  /// normalized kino.pub title/name -> EPG target (a channel id or display-name) from the map file.
  private let overrideByNorm: [String: String]
  /// Filled while parsing the `<channel>` block.
  private var epgChannelNames: [String: String] = [:]   // XMLTV channel id -> normalized display-name
  private var epgIDs: Set<String> = []                  // every XMLTV channel id seen
  /// XMLTV channel id -> kino.pub channel ids, resolved once before the first `<programme>`.
  private var epgToKino: [String: [Int]] = [:]
  private var matchesResolved = false

  private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyyMMddHHmmss Z"
    return formatter
  }()

  // Parse state
  private var currentChannelID: String?
  private var inDisplayName = false
  private var displayNameBuffer = ""

  private var programmeKinoIDs: [Int]?
  private var programmeStart: Date?
  private var programmeStop: Date?
  private var inProgrammeTitle = false
  private var titleBuffer = ""

  init(channels: [TVChannel], overrides: [String: String], pastCutoff: Date, futureCutoff: Date) {
    self.channels = channels
    self.pastCutoff = pastCutoff
    self.futureCutoff = futureCutoff
    var byNorm: [String: String] = [:]
    for (key, value) in overrides {
      let norm = Self.normalize(key)
      if !norm.isEmpty { byNorm[norm] = value }
    }
    self.overrideByNorm = byNorm
    super.init()
  }

  /// Generic words dropped before comparing names, so "Матч ТВ" == "Матч!" and "КХЛ ТВ" == "КХЛ".
  private static let stopwords: Set<String> = ["tv", "тв", "hd", "fhd", "uhd", "uhdtv", "fullhd", "4k"]

  /// lowercased, ё→е, split into alphanumeric tokens, generic tokens dropped, rejoined.
  /// Country tags stay distinct ("eurosport1" vs "eurosport1pl"); never reduces to empty.
  static func normalize(_ value: String) -> String {
    let lowered = value.lowercased().replacingOccurrences(of: "ё", with: "е")
    let tokens = lowered.unicodeScalars
      .split { !CharacterSet.alphanumerics.contains($0) }
      .map { String(String.UnicodeScalarView($0)) }
    let kept = tokens.filter { !stopwords.contains($0) }
    let joined = kept.joined()
    return joined.isEmpty ? tokens.joined() : joined
  }

  /// Resolve an override target (an EPG channel id present in the feed, or a display-name) to its id.
  private func resolveTarget(_ raw: String, normNameToEpgID: [String: String]) -> String? {
    if epgIDs.contains(raw) { return raw }                 // value is a literal EPG channel id
    return normNameToEpgID[Self.normalize(raw)]            // value is an EPG display-name
  }

  private func resolveMatchesIfNeeded() {
    guard !matchesResolved else { return }
    matchesResolved = true

    var normNameToEpgID: [String: String] = [:]
    for (id, name) in epgChannelNames where normNameToEpgID[name] == nil { normNameToEpgID[name] = id }

    for channel in channels {
      let normTitle = Self.normalize(channel.title)
      let normName = channel.name.map(Self.normalize) ?? ""

      var epgID: String?
      // 1) Explicit override (by title, then by secondary name), pointing at a channel in the feed.
      if let raw = overrideByNorm[normTitle] ?? (normName.isEmpty ? nil : overrideByNorm[normName]) {
        epgID = resolveTarget(raw, normNameToEpgID: normNameToEpgID)
      }
      // 2) Fallback: automatic normalized-name match.
      if epgID == nil {
        epgID = normNameToEpgID[normTitle] ?? (normName.isEmpty ? nil : normNameToEpgID[normName])
      }
      if let epgID { epgToKino[epgID, default: []].append(channel.id) }
    }
  }

  func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
              qualifiedName qName: String?, attributes attributeDict: [String: String]) {
    switch elementName {
    case "channel":
      currentChannelID = attributeDict["id"]
      if let id = currentChannelID { epgIDs.insert(id) }
    case "display-name":
      inDisplayName = true
      displayNameBuffer = ""
    case "programme":
      resolveMatchesIfNeeded()
      programmeKinoIDs = nil
      programmeStart = nil
      programmeStop = nil
      titleBuffer = ""
      guard let channelID = attributeDict["channel"], let ids = epgToKino[channelID] else { return }
      programmeKinoIDs = ids
      programmeStart = attributeDict["start"].flatMap { dateFormatter.date(from: $0) }
      programmeStop = attributeDict["stop"].flatMap { dateFormatter.date(from: $0) }
    case "title":
      if programmeKinoIDs != nil {
        inProgrammeTitle = true
        titleBuffer = ""
      }
    default:
      break
    }
  }

  func parser(_ parser: XMLParser, foundCharacters string: String) {
    if inDisplayName {
      displayNameBuffer += string
    } else if inProgrammeTitle {
      titleBuffer += string
    }
  }

  func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
              qualifiedName qName: String?) {
    switch elementName {
    case "display-name":
      inDisplayName = false
      if let id = currentChannelID {
        let normalized = Self.normalize(displayNameBuffer)
        if !normalized.isEmpty, epgChannelNames[id] == nil { epgChannelNames[id] = normalized }
      }
    case "channel":
      currentChannelID = nil
    case "title":
      inProgrammeTitle = false
    case "programme":
      defer {
        programmeKinoIDs = nil
        programmeStart = nil
        programmeStop = nil
      }
      guard let ids = programmeKinoIDs,
            let start = programmeStart,
            let stop = programmeStop,
            stop > start,
            stop > pastCutoff, start < futureCutoff else { return }
      let title = titleBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !title.isEmpty else { return }
      let program = EPGProgram(title: title, start: start, stop: stop)
      for id in ids { programs[id, default: []].append(program) }
    default:
      break
    }
  }
}
