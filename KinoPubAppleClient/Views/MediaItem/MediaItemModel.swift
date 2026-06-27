//
//  MediaItemModel.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 2.08.2023.
//

import Foundation
import KinoPubBackend
import OSLog
import KinoPubLogging
import KinoPubKit
import KinoPubUI

/// The current user's like/dislike choice for a title (this session only).
public enum UserVote: Equatable {
  case none, up, down
}

@MainActor
class MediaItemModel: ObservableObject {

  private var itemsService: VideoContentService
  private var actionsService: UserActionsService
  private var downloadManager: DownloadManager<DownloadMeta>
  private var errorHandler: ErrorHandler
  public var linkProvider: NavigationLinkProvider
  public var mediaItemId: Int

  @Published public var mediaItem: MediaItem = MediaItem.mock()
  @Published public var itemLoaded: Bool = false
  /// The user's like/dislike for this title this session. kino.pub voting is ONE-TIME (you can't
  /// change a cast vote), and there's no API to read a prior vote, so this starts `.none` each session.
  @Published public var myVote: UserVote = .none
  /// Like / dislike counts shown next to the ratings — seeded from the item, refreshed after a vote.
  @Published public var likeCount: Int = 0
  @Published public var dislikeCount: Int = 0
  /// Transient typed message shown as a toast (e.g. after toggling a bookmark).
  @Published public var toastMessage: ToastMessage?
  @Published public var relatedItems: [MediaItem] = []
  /// "More from this director" / "More with this actor" shelves (via /v1/items?director=/cast=).
  @Published public var moreFromDirector: [MediaItem] = []
  @Published public var moreWithActor: [MediaItem] = []
  /// Kinopoisk-sourced extras (facts / reviews / full crew / stills) via the kpapp.link kpapi proxy.
  /// Best-effort: empty when the title has no Kinopoisk id or a request fails.
  @Published public var facts: [KpFact] = []
  @Published public var reviews: KpReviewsPage = .empty
  @Published public var staff: [KpStaffMember] = []
  @Published public var images: [KpImage] = []
  // Per-group "finished loading" flags so the view can reserve space with a skeleton shelf while a
  // dynamically-loaded block is in flight, then swap content in place (or collapse) — instead of the
  // section popping in from zero height and shoving the rest of the page around.
  @Published public var relatedLoaded: Bool = false
  @Published public var moreFromLoaded: Bool = false
  @Published public var moreWithLoaded: Bool = false
  @Published public var extrasLoaded: Bool = false
  private let extrasService = KinopoiskExtrasService()
  public var primaryDirector: String? { directorNames.first }
  public var primaryActor: String? { castNames.first }
  /// Effective watched state for an episode (client optimistic override first, then server data).
  public func isEpisodeWatched(_ episode: Episode) -> Bool {
    AppContext.shared.libraryState.episodeWatched(episodeId: episode.id, serverWatched: episode.watched > 0)
  }

  /// Effective watched state for a movie (client optimistic override first, then server data).
  public var isMovieWatched: Bool {
    AppContext.shared.libraryState.movieWatched(itemId: mediaItemId,
                                                serverWatched: (mediaItem.videos?.first?.watched ?? 0) > 0)
  }

  private let localProgressStore: LocalWatchProgressStore = AppContext.shared.localProgressStore
  /// Bumped when the screen reappears (e.g. back from the player) so the local-progress overlay
  /// re-reads the store immediately, before the authoritative server refetch returns.
  @Published private var localProgressTick: Int = 0

  // MARK: - Local watch progress overlay (instant resume feedback, "Netflix-style")

  /// The locally recorded resume point for THIS item, if any. The store keeps one entry per item
  /// (the most-recently-watched video/episode), keyed by `(season, episode)`.
  private var localEntry: LocalWatchEntry? {
    localProgressStore.allEntries().first { $0.id == mediaItemId }
  }

  /// Locally recorded resume position (seconds) for a specific video/episode of this item, or 0.
  /// Movie matches by id (season nil); an episode requires an exact `(season, episode)` match.
  public func localResumeSeconds(season: Int?, episode: Int?) -> Int {
    guard let entry = localProgressStore.entry(forId: mediaItemId, season: season, episode: episode) else { return 0 }
    return Int(entry.position)
  }

  /// Local progress fraction [0,1] for a specific video/episode, or nil if nothing recorded.
  public func localProgressFraction(season: Int?, episode: Int?) -> Double? {
    guard let entry = localProgressStore.entry(forId: mediaItemId, season: season, episode: episode),
          entry.duration > 0 else { return nil }
    return min(max(entry.position / entry.duration, 0), 1)
  }

  /// For a series with no server-side continue point yet, the (season, episode) to resume based on
  /// the local store — so the play button reads "Continue" instantly after watching, pre-refetch.
  public func localSeriesContinue() -> (season: Season, episode: Episode)? {
    guard mediaItem.isSeries, let entry = localEntry,
          let season = mediaItem.seasons?.first(where: { $0.number == entry.season }),
          let episode = season.episodes.first(where: { $0.number == entry.episode }) else { return nil }
    return (season, episode)
  }

  /// Call when the detail screen reappears (returning from the player). Re-reads local progress for
  /// instant feedback and refetches authoritative server progress. No-op before the first load,
  /// which is handled by `fetchData()` in the view's `.task`.
  func refreshOnReappear() {
    guard itemLoaded else { return }
    localProgressTick &+= 1
    fetchData()
  }

  /// Actor names parsed from the comma-separated `cast` field (trimmed, non-empty).
  public var castNames: [String] {
    mediaItem.cast
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  /// Director names parsed from the comma-separated `director` field.
  public var directorNames: [String] {
    mediaItem.director
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }


  /// The content type to use for facet filters opened from this item, so a
  /// serial's genre opens serials and a movie's opens movies.
  private var facetContentType: MediaType {
    MediaType(rawValue: mediaItem.type) ?? .movie
  }

  private func facetFilter(genres: [Int] = [], countries: [Int] = [], year: String? = nil) -> MediaItemsFilter {
    MediaItemsFilter(contentType: facetContentType,
                     genres: genres,
                     countries: countries,
                     year: year,
                     age: nil,
                     sort: nil)
  }

  // MARK: - Facet filters (for deep-linking into the section)

  func genreFilter(id: Int) -> MediaItemsFilter { facetFilter(genres: [id]) }
  func countryFilter(id: Int) -> MediaItemsFilter { facetFilter(countries: [id]) }
  func yearFilter(_ year: Int) -> MediaItemsFilter { facetFilter(year: "\(year)") }

  // MARK: - Tappable metadata routes

  /// Route to a catalog filtered by a single genre.
  func genreRoute(id: Int, title: String) -> (any Hashable)? {
    linkProvider.filteredCatalog(filter: facetFilter(genres: [id]), title: title)
  }

  /// Route to a catalog filtered by a single country.
  func countryRoute(id: Int, title: String) -> (any Hashable)? {
    linkProvider.filteredCatalog(filter: facetFilter(countries: [id]), title: title)
  }

  /// Route to a catalog filtered by a single year.
  func yearRoute(_ year: Int) -> (any Hashable)? {
    linkProvider.filteredCatalog(filter: facetFilter(year: "\(year)"), title: "\(year)")
  }

  /// Route to a person search for an actor (kino.pub `field=cast`).
  func actorRoute(_ name: String) -> (any Hashable)? {
    linkProvider.personSearch(query: name, field: "cast", title: name)
  }

  /// Route to a person search for a director (kino.pub `field=director`).
  func directorRoute(_ name: String) -> (any Hashable)? {
    linkProvider.personSearch(query: name, field: "director", title: name)
  }

  init(mediaItemId: Int,
       itemsService: VideoContentService,
       downloadManager: DownloadManager<DownloadMeta>,
       linkProvider: NavigationLinkProvider,
       errorHandler: ErrorHandler,
       actionsService: UserActionsService = AppContext.shared.actionsService) {
    self.itemsService = itemsService
    self.mediaItemId = mediaItemId
    self.linkProvider = linkProvider
    self.errorHandler = errorHandler
    self.downloadManager = downloadManager
    self.actionsService = actionsService
  }

  func fetchData() {
    Task {
      do {
        mediaItem = try await itemsService.fetchDetails(for: "\(mediaItemId)").item
        let mediaId = mediaItem.id
        mediaItem.seasons = mediaItem.seasons?.map({ $0.mediaId = mediaId; return $0 })
        itemLoaded = true
        seedVoteCounts()
        // Reconcile optimistic watched overrides against fresh server data: drop the ones the
        // server now confirms (keeps any still-in-flight toggle), so the server can drive again.
        AppContext.shared.libraryState.reconcileWatched(
          movieItemId: mediaId,
          serverMovieWatched: mediaItem.isSeries ? nil : (mediaItem.videos?.first?.watched ?? 0) > 0,
          episodes: mediaItem.orderedEpisodes.map { (id: $0.episode.id, watched: $0.episode.watched > 0) })
        // Seed the client library state once (bookmark folders + watchlist) so the UI reflects
        // membership instantly; optimistic toggles thereafter aren't clobbered by refetches.
        AppContext.shared.libraryState.seedIfAbsent(itemId: mediaId,
                                                    folderIds: mediaItem.bookmarks?.map { $0.id } ?? [],
                                                    inWatchlist: mediaItem.inWatchlist == true)
        fetchRelated()
        fetchPeopleShelves()
        fetchExtras()
      } catch {
        errorHandler.setError(error)
      }
    }
  }

  /// Loads items similar to the current one (same primary genre & content type)
  /// using the catalog filter endpoint. Errors are surfaced but never fatal.
  func fetchRelated() {
    Task {
      do {
        let contentType = MediaType(rawValue: mediaItem.type) ?? .movie
        var genres: [Int] = []
        if let genreId = mediaItem.genres.first?.id {
          genres.append(genreId)
        }
        let filter = MediaItemsFilter(contentType: contentType,
                                      genres: genres,
                                      countries: [],
                                      year: nil,
                                      age: nil,
                                      sort: nil)
        let response = try await itemsService.filter(filter: filter, page: nil)
        relatedItems = response.items
          .filter { $0.id != mediaItem.id }
          .prefix(15)
          .map { $0 }
      } catch {
        errorHandler.setError(error)
      }
      relatedLoaded = true
    }
  }

  /// "More from director" / "More with actor" shelves, mirroring the web detail page. Best-effort:
  /// a failure just leaves the shelf empty (no error banner).
  func fetchPeopleShelves() {
    let contentType = MediaType(rawValue: mediaItem.type) ?? .movie
    if let director = directorNames.first {
      Task {
        let filter = MediaItemsFilter(contentType: contentType, genres: [], countries: [],
                                      year: nil, age: nil, sort: "rating-", director: director)
        if let response = try? await itemsService.filter(filter: filter, page: nil) {
          moreFromDirector = response.items.filter { $0.id != mediaItem.id }.prefix(15).map { $0 }
        }
        moreFromLoaded = true
      }
    } else {
      moreFromLoaded = true
    }
    if let actor = castNames.first {
      Task {
        let filter = MediaItemsFilter(contentType: contentType, genres: [], countries: [],
                                      year: nil, age: nil, sort: "rating-", cast: actor)
        if let response = try? await itemsService.filter(filter: filter, page: nil) {
          moreWithActor = response.items.filter { $0.id != mediaItem.id }.prefix(15).map { $0 }
        }
        moreWithLoaded = true
      }
    } else {
      moreWithLoaded = true
    }
  }

  func startDownload(item: DownloadableMediaItem, file: FileInfo) {
    let meta = DownloadMeta.make(from: item, quality: file.quality)
#if os(iOS)
    // Prefer the HLS master so the offline copy keeps full quality + every audio track (озвучка) +
    // subtitles, switchable during playback (mp4 would bake in a single track). macOS falls back to mp4.
    if let hlsURL = URL(string: file.url.hls4) {
      switch AppContext.shared.hlsDownloadManager.startDownload(meta: meta, hlsURL: hlsURL) {
      case .started:
        toastMessage = .success("Download started".localized)
      case .alreadyDownloading:
        toastMessage = .info("Already downloading".localized)
      case .alreadyDownloaded:
        toastMessage = .info("Already downloaded".localized)
      case .failed(let reason):
        toastMessage = .error(reason)
      }
      return
    }
#endif
    guard let url = URL(string: file.url.http) else {
      toastMessage = .error("Couldn't start download".localized)
      return
    }
    _ = downloadManager.startDownload(url: url, withMetadata: meta)
    toastMessage = .success("Download started".localized)
  }

  /// Enqueues every episode of `season`. `quality` of nil downloads the best available per episode.
  func downloadSeason(_ season: Season, quality: String?) {
    let count = AppContext.shared.seasonDownloadManager.downloadSeason(
      mediaId: mediaItem.id,
      seriesTitle: mediaItem.localizedTitle,
      season: season,
      quality: quality)
    toastMessage = count > 0
      ? .success(String(format: "%d episodes queued".localized, count))
      : .warning("Nothing to download".localized)
  }

  func toggleWatched() {
    let newState = !isMovieWatched
    AppContext.shared.libraryState.setMovieWatched(itemId: mediaItemId, value: newState)  // optimistic
    Task {
      do {
        try await actionsService.toggleWatching(id: mediaItemId, video: nil, season: nil)
        toastMessage = newState ? .success("Marked as watched".localized) : .info("Marked as unwatched".localized)
      } catch {
        AppContext.shared.libraryState.setMovieWatched(itemId: mediaItemId, value: !newState)  // revert
        errorHandler.setError(error)
      }
    }
  }

  func toggleEpisodeWatched(episode: Episode, season: Int) {
    let newState = !isEpisodeWatched(episode)
    AppContext.shared.libraryState.setEpisodeWatched(episodeId: episode.id, value: newState)  // optimistic
    Task {
      do {
        try await actionsService.toggleWatching(id: mediaItemId, video: episode.number, season: season)
        toastMessage = newState ? .success("Marked as watched".localized) : .info("Marked as unwatched".localized)
      } catch {
        AppContext.shared.libraryState.setEpisodeWatched(episodeId: episode.id, value: !newState)  // revert
        errorHandler.setError(error)
      }
    }
  }

  func toggleWatchlist() {
    let current = AppContext.shared.libraryState.inWatchlist(itemId: mediaItemId) ?? (mediaItem.inWatchlist == true)
    let newState = !current
    AppContext.shared.libraryState.setWatchlist(itemId: mediaItemId, value: newState)  // optimistic
    Task {
      do {
        try await actionsService.toggleWatchlist(id: mediaItemId)
        toastMessage = newState ? .success("Added to watchlist".localized) : .info("Removed from watchlist".localized)
      } catch {
        AppContext.shared.libraryState.setWatchlist(itemId: mediaItemId, value: current)  // revert
        errorHandler.setError(error)
      }
    }
  }

  func loadBookmarkFolders() {
    // Cached once per session in the library store; no refetch on every detail-screen appearance.
    Task { await AppContext.shared.libraryState.loadBookmarkFoldersIfNeeded() }
  }

  func toggleBookmark(folderId: Int, folderTitle: String) {
    let nowIn = AppContext.shared.libraryState.toggleBookmark(itemId: mediaItemId, folderId: folderId)  // optimistic
    Task {
      do {
        try await actionsService.toggleBookmark(itemId: mediaItemId, folderId: folderId)
        toastMessage = nowIn
          ? .success(String(format: "Saved to %@".localized, folderTitle))
          : .info(String(format: "Removed from %@".localized, folderTitle))
      } catch {
        AppContext.shared.libraryState.setBookmark(itemId: mediaItemId, folderId: folderId, isOn: !nowIn)  // revert
        errorHandler.setError(error)
      }
    }
  }

  /// Cast a like (`up: true` → `like=1`) or dislike (`up: false` → `like=0`). kino.pub votes are
  /// one-time: the API answers `voted: true` when counted, or `voted: false` when the user already
  /// voted (it can't be changed). We optimistically highlight + update the count, reverting if the
  /// server says it didn't count.
  /// Load Kinopoisk extras (facts / reviews / crew / stills) for this title via the kpapp.link proxy.
  /// Requires a Kinopoisk id; each request is independent and best-effort (a failure hides its section).
  func fetchExtras() {
    // No Kinopoisk id → there will never be extras; mark loaded so the view doesn't reserve skeleton
    // space for sections that can't appear.
    guard let filmId = mediaItem.kinopoisk, filmId > 0 else {
      extrasLoaded = true
      return
    }
    // Resolve all four together and publish once, so the extras block settles in a single layout
    // change (with the skeleton reserving its space) instead of four staggered pops.
    Task {
      async let f = extrasService.facts(filmId: filmId)
      async let r = extrasService.reviews(filmId: filmId)
      async let s = extrasService.staff(filmId: filmId)
      async let i = extrasService.images(filmId: filmId)
      facts = (try? await f) ?? []
      reviews = (try? await r) ?? .empty
      staff = (try? await s) ?? []
      images = (try? await i) ?? []
      extrasLoaded = true
    }
  }

  /// kino.pub gives the aggregate as `rating_votes` (total) + `rating_percentage` (% positive), not
  /// separate like/dislike counts, so derive them for the initial display. A real vote refreshes them.
  /// Also restores the user's own remembered vote so their like/dislike stays visible on revisits.
  private func seedVoteCounts() {
    myVote = AppContext.shared.libraryState.userVote(itemId: mediaItemId).map { $0 ? .up : .down } ?? .none
    let total = mediaItem.ratingVotes
    guard total > 0 else { likeCount = 0; dislikeCount = 0; return }
    let positive = Int((Double(total) * mediaItem.ratingPercentage / 100.0).rounded())
    likeCount = min(max(positive, 0), total)
    dislikeCount = total - likeCount
  }

  func vote(up: Bool) {
    let target: UserVote = up ? .up : .down
    // kino.pub votes are permanent: you can't switch a like to a dislike (or re-cast).
    if myVote == target { return }
    if myVote != .none {
      toastMessage = .info("You've already rated this".localized)
      return
    }
    // First vote for this title: optimistic highlight + count bump, remembered locally so it persists.
    myVote = target
    AppContext.shared.libraryState.setUserVote(itemId: mediaItemId, up: up)
    if up { likeCount += 1 } else { dislikeCount += 1 }
    Task {
      do {
        let result = try await actionsService.vote(id: mediaItemId, like: up ? 1 : 0)
        if result.voted {
          // Server counted it — trust its fresh totals.
          if let p = result.positive.flatMap({ Int($0) }) { likeCount = p }
          if let n = result.negative.flatMap({ Int($0) }) { dislikeCount = n }
        } else {
          // The account already voted earlier (e.g. on another device). Keep the user's choice
          // visible, but undo the optimistic bump since the server didn't count it again.
          if up { likeCount = max(0, likeCount - 1) } else { dislikeCount = max(0, dislikeCount - 1) }
        }
        toastMessage = .success(up ? "Liked".localized : "Disliked".localized)
      } catch {
        // Network failure — fully revert (including the remembered vote).
        myVote = .none
        AppContext.shared.libraryState.clearUserVote(itemId: mediaItemId)
        if up { likeCount = max(0, likeCount - 1) } else { dislikeCount = max(0, dislikeCount - 1) }
        errorHandler.setError(error)
      }
    }
  }

  /// Create a new bookmark folder and put this item in it, then refresh the shared folder list.
  func createFolderAndAdd(named name: String) {
    let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else { return }
    Task {
      do {
        let folderId = try await actionsService.createBookmarkFolder(title: title)
        try await actionsService.toggleBookmark(itemId: mediaItemId, folderId: folderId)
        AppContext.shared.libraryState.setBookmark(itemId: mediaItemId, folderId: folderId, isOn: true)
        await AppContext.shared.libraryState.reloadBookmarkFolders()
        toastMessage = .success(String(format: "Saved to %@".localized, title))
      } catch {
        errorHandler.setError(error)
      }
    }
  }

}
