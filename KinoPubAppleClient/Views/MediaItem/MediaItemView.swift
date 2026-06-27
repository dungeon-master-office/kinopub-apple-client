//
//  MediaItemView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 28.07.2023.
//

import Foundation
import SwiftUI
import KinoPubUI
import KinoPubBackend
import KinoPubKit
import SkeletonUI

struct MediaItemView: View {

  @EnvironmentObject var errorHandler: ErrorHandler
  @EnvironmentObject private var navigationState: NavigationState
  @EnvironmentObject private var libraryState: MediaLibraryStore
  @Environment(\.appContext) private var appContext
#if os(iOS)
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif
  @StateObject private var itemModel: MediaItemModel

  @State private var plotExpanded: Bool = false
  @State private var selectedSeasonNumber: Int?
  @State private var showComments: Bool = false
  @State private var showCastCrew: Bool = false
  @State private var showFacts: Bool = false
  @State private var showReviews: Bool = false
  /// Non-nil when the full-screen stills viewer is open, holding the index being shown.
  @State private var stillSelection: StillSelection?
  @State private var showCreateFolder: Bool = false
  @State private var newFolderName: String = ""
  /// Preferred 3D view mode (shared with the player via UserDefaults). Picked here for 3D titles.
  @AppStorage("preferredThreeDMode") private var threeDModeRaw: String = ThreeDMode.sbsMono.rawValue
  /// Person picked in the Cast & Crew modal — pushed onto this page's stack after the modal closes.
  @State private var pendingPersonRoute: Route?
  @State private var showPerson: Bool = false

  init(model: @autoclosure @escaping () -> MediaItemModel) {
    _itemModel = StateObject(wrappedValue: model())
  }

  private var mediaItem: MediaItem { itemModel.mediaItem }
  private var isSkeleton: Bool { !itemModel.itemLoaded }

  /// True when the app uses the sidebar (iPad/macOS) so facets can deep-link into a section.
  private var usesSidebarSections: Bool {
#if os(macOS)
    return true
#else
    return horizontalSizeClass == .regular
#endif
  }

  /// A tappable facet (genre/country/year). On wide layouts it selects the matching Library
  /// section in the sidebar and pre-filters it; on compact it pushes a filtered catalog.
  @ViewBuilder
  private func sectionFacet<Label: View>(filter: MediaItemsFilter,
                                         route: (any Hashable)?,
                                         @ViewBuilder label: () -> Label) -> some View {
    if usesSidebarSections {
      Button {
        navigationState.pendingCategoryFilter = filter
        navigationState.sidebarSelection = .category(filter.contentType)
      } label: {
        label()
      }
      .buttonStyle(.plain)
    } else {
      facetLink(route, label: label)
    }
  }

  /// Wraps `label` in a NavigationLink to `route` when one exists; otherwise
  /// renders the label as-is. Lets tappable metadata degrade gracefully on
  /// link providers that don't support facet routes.
  @ViewBuilder
  private func facetLink<Label: View>(_ route: (any Hashable)?, @ViewBuilder label: () -> Label) -> some View {
    if let route {
      NavigationLink(value: route) {
        label()
      }
      .buttonStyle(.plain)
    } else {
      label()
    }
  }

  var body: some View {
    ScrollView(.vertical) {
      VStack(alignment: .leading, spacing: 28) {
        hero
        episodesSection
        trailersSection
        imagesSection
        castSection
        descriptionSection
        factsSection
        reviewsSection
        relatedSection
        moreFromDirectorSection
        moreWithActorSection
        infoSection
        commentsSection
      }
      .padding(.bottom, 32)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(Color.KinoPub.background)
    .sheet(isPresented: $showComments) {
      CommentsView(mediaId: mediaItem.id)
    }
    .sheet(isPresented: $showCastCrew, onDismiss: {
      // The modal closed; if a person was picked, open their section on this page.
      if pendingPersonRoute != nil { showPerson = true }
    }) {
      CastCrewView(directors: itemModel.directorNames,
                   actors: itemModel.castNames,
                   staff: itemModel.staff,
                   onSelect: { name, field in
                     pendingPersonRoute = .personSearch(name, field, name)
                   })
    }
    // Programmatic push (iOS 16-compatible) onto whichever stack this page lives in.
    .navigationDestination(isPresented: $showPerson) {
      if let route = pendingPersonRoute {
        RouteDestinationView(route: route)
      }
    }
    .onChange(of: showPerson) { presented in
      if !presented { pendingPersonRoute = nil }
    }
    .sheet(isPresented: $showFacts) {
      FactsView(facts: itemModel.facts)
    }
    .sheet(isPresented: $showReviews) {
      ReviewsView(reviews: itemModel.reviews)
    }
    .sheet(item: $stillSelection) { selection in
      StillsViewer(images: itemModel.images, startIndex: selection.index)
    }
    .alert("New folder".localized, isPresented: $showCreateFolder) {
      TextField("Folder name".localized, text: $newFolderName)
      Button("Cancel".localized, role: .cancel) {}
      Button("Create".localized) { itemModel.createFolderAndAdd(named: newFolderName) }
    }
    .toast(message: $itemModel.toastMessage)
    #if os(iOS)
    .toolbar(.hidden, for: .tabBar)
    #endif
    // iOS 26: the hero backdrop bleeds under the glass bar. Pre-26: frosted bar + restored safe area.
    .heroNavBar()
    .task {
      itemModel.fetchData()
      itemModel.loadBookmarkFolders()
    }
    // Returning from the player: re-read local progress for instant feedback and refetch the
    // server so the resume button and episode progress bars reflect what was just watched.
    .onAppear {
      itemModel.refreshOnReappear()
    }
    // Cache artwork/title locally so a started title can resume in Continue Watching.
    .onChange(of: itemModel.itemLoaded) { loaded in
      if loaded {
        appContext.localProgressStore.cacheItem(itemModel.mediaItem)
      }
    }
    .handleError(state: $errorHandler.state)
  }

  // MARK: - Hero

  private var hero: some View {
    HeroBackdrop(imageURL: mediaItem.posters.wide ?? mediaItem.posters.big, height: 552, tallBlur: true, blurReduction: 50) {
      VStack(alignment: .leading, spacing: 10) {
        Text(mediaItem.localizedTitle)
          .font(.system(size: 34, weight: .bold))
          .foregroundStyle(.white)
          .skeleton(enabled: isSkeleton, size: CGSize(width: 240, height: 36))

        Text(genreLine)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(.white)
          .skeleton(enabled: isSkeleton, size: CGSize(width: 180, height: 16))

        if !mediaItem.plot.isEmpty {
          VStack(alignment: .leading, spacing: 4) {
            Text(mediaItem.plot)
              .font(.system(size: 14))
              .foregroundStyle(.white.opacity(0.95))
              .lineLimit(plotExpanded ? nil : 2)
              .multilineTextAlignment(.leading)
            Button(plotExpanded ? "Свернуть" : "ЕЩЕ") {
              withAnimation { plotExpanded.toggle() }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.KinoPub.accent)
            .buttonStyle(.plain)
          }
        }

        MetadataRow(items: heroBadges)

        // kino.pub / КП / IMDb badges in the hero (no background pill here).
        // Ratings + the user's like/dislike, side by side — wraps to two rows on narrow screens.
        let ratings = ContentItemRatingView(imdbScore: mediaItem.imdbRating,
                                            kinopoiskScore: mediaItem.kinopoiskRating,
                                            kinopubScore: mediaItem.ratingPercentage > 0 ? mediaItem.ratingPercentage / 10.0 : nil,
                                            showsBackground: false)
        ViewThatFits(in: .horizontal) {
          HStack(spacing: 12) { ratings; voteControl }
          VStack(alignment: .leading, spacing: 8) { ratings; voteControl }
        }

        heroActions
          .padding(.top, 6)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var genreLine: String {
    let typeTitle = (MediaType(rawValue: mediaItem.type)?.title) ?? ""
    var parts: [String] = []
    if !typeTitle.isEmpty { parts.append(typeTitle) }
    parts.append(contentsOf: mediaItem.genres.compactMap { $0.title })
    return parts.joined(separator: " · ")
  }

  private var heroBadges: [MetadataRow.Item] {
    var items: [MetadataRow.Item] = []
    if mediaItem.year > 0 {
      items.append(.init(text: "\(mediaItem.year)", isBadge: false))
    }
    // Year + country in the hero for both movies and series.
    if let country = mediaItem.countries.first?.title, !country.isEmpty {
      items.append(.init(text: country, isBadge: false))
    }
    // Movies also show their runtime in the hero; for series the durations live in the info block.
    if !mediaItem.isSeries {
      let duration = mediaItem.duration.totalFormatted
      if !duration.isEmpty {
        items.append(.init(text: duration, isBadge: false))
      }
    }
    if let quality = qualityBadgeText {
      items.append(.init(text: quality, isBadge: true))
    }
    if let ac3 = mediaItem.ac3, ac3 > 0 {
      items.append(.init(text: "AC3", isBadge: true))
    }
    return items
  }

  /// Best-effort quality badge. `quality` carries the max vertical resolution
  /// (e.g. 2160, 1080). We only show a badge when the value is meaningful.
  private var qualityBadgeText: String? {
    switch mediaItem.quality {
    case let q where q >= 2160: return "4K"
    case let q where q >= 720: return "HD"
    default: return nil
    }
  }

  // MARK: - Hero actions

  @ViewBuilder
  private var heroActions: some View {
    if usesSidebarSections {
      // Wide (iPad/macOS): everything on one row.
      HStack(spacing: 12) {
        playButton
        secondaryActions
      }
    } else {
      // Narrow (iPhone): the play button gets its own full-width row; the circle actions sit below.
      VStack(spacing: 14) {
        playButton
        HStack(spacing: 12) {
          secondaryActions
          Spacer(minLength: 0)
        }
      }
    }
  }

  @ViewBuilder
  private var secondaryActions: some View {
    // Watchlist ("Буду смотреть") is a serials-only feature on kino.pub; for movies use Bookmarks.
    if mediaItem.isSeries {
      watchlistButton
    } else {
      // Whole-item "watched" applies to movies; series are marked per-episode (long-press).
      watchedButton
    }
    bookmarkMenu
    downloadButton
    if mediaItem.type.lowercased() == "3d" {
      threeDModeButton
    }
    // Trailer button removed from the hero — the Trailers shelf below already exposes it.
    // Like/dislike moved next to the ratings (see `voteControl`).
  }

  /// 3D view-mode picker for 3D titles (Side-by-Side / Over-Under × 2D / Anaglyph). Writes the
  /// shared preference the player reads — on a flat screen true stereo can't be shown, so it's either
  /// one eye as 2D or a red-cyan anaglyph (for glasses).
  @ViewBuilder
  private var threeDModeButton: some View {
    Menu {
      ForEach(ThreeDMode.allCases) { mode in
        Button { threeDModeRaw = mode.rawValue } label: {
          if threeDModeRaw == mode.rawValue {
            Label(mode.title.localized, systemImage: "checkmark")
          } else {
            Text(mode.title.localized)
          }
        }
      }
    } label: {
      circleIcon("cube")
    }
    .menuIndicator(.hidden)
    #if os(macOS)
    .menuStyle(.button)
    .buttonStyle(.plain)
    .fixedSize()
    #endif
    .accessibilityLabel("3D mode")
  }

  private var watchlistButton: some View {
    // Optimistic client state first, server flag as the fallback.
    let inWatchlist = libraryState.inWatchlist(itemId: mediaItem.id) ?? (mediaItem.inWatchlist == true)
    return circleIconButton(inWatchlist ? "checkmark" : "plus",
                            accessibility: inWatchlist ? "Remove from Watchlist" : "Add to Watchlist") {
      itemModel.toggleWatchlist()
    }
  }

  /// Like / dislike pills with their counts, shown next to the ratings. kino.pub voting is one-time.
  private var voteControl: some View {
    HStack(spacing: 8) {
      voteButton(up: true)
      voteButton(up: false)
    }
  }

  private func voteButton(up: Bool) -> some View {
    let active = itemModel.myVote == (up ? .up : .down)
    let count = up ? itemModel.likeCount : itemModel.dislikeCount
    let filled = up ? "hand.thumbsup.fill" : "hand.thumbsdown.fill"
    let outline = up ? "hand.thumbsup" : "hand.thumbsdown"
    // Active like uses the kino.pub chip colour so it reads as part of the rating; dislike turns red.
    let activeColor: Color = up ? RatingBrand.kinopubTeal : Color(red: 0.88, green: 0.36, blue: 0.36)
    let activeForeground: Color = up ? .black : .white
    return Button {
      itemModel.vote(up: up)
    } label: {
      HStack(spacing: 5) {
        Image(systemName: active ? filled : outline)
          .font(.system(size: 13, weight: .semibold))
        if count > 0 {
          Text(NumberFormatter.localizedString(from: NSNumber(value: count), number: .decimal))
            .font(.system(size: 13, weight: .semibold))
        }
      }
      .foregroundStyle(active ? activeForeground : Color.KinoPub.text)
      .padding(.horizontal, 11)
      .padding(.vertical, 6)
      .background(Capsule(style: .continuous)
        .fill(active ? activeColor : Color.KinoPub.selectionBackground))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(up ? "Like" : "Dislike")
  }

  private var watchedButton: some View {
    let watched = itemModel.isMovieWatched
    return circleIconButton(watched ? "eye.fill" : "eye",
                            accessibility: watched ? "Mark as Unwatched" : "Mark as Watched") {
      itemModel.toggleWatched()
    }
  }

  @ViewBuilder
  private var bookmarkMenu: some View {
    Menu {
      ForEach(libraryState.bookmarkFolders) { folder in
        let isOn = libraryState.isBookmarked(itemId: mediaItem.id, folderId: folder.id)
        Button {
          itemModel.toggleBookmark(folderId: folder.id, folderTitle: folder.title)
        } label: {
          // A checkmark marks folders this item is already in (was previously write-only/blind).
          if isOn {
            Label(folder.title, systemImage: "checkmark")
          } else {
            Text(folder.title)
          }
        }
      }
      Divider()
      Button {
        newFolderName = ""
        showCreateFolder = true
      } label: {
        Label("New folder…".localized, systemImage: "folder.badge.plus")
      }
    } label: {
      // Fill the icon when the item is in at least one folder.
      circleIcon(libraryState.isInAnyBookmarkFolder(itemId: mediaItem.id) ? "folder.fill" : "folder")
    }
    .menuIndicator(.hidden)
    #if os(macOS)
    // `.button` + `.plain` renders our circle label faithfully (borderlessButton strips the
    // background and tints the symbol with the accent colour).
    .menuStyle(.button)
    .buttonStyle(.plain)
    .fixedSize()
    #endif
    .accessibilityLabel("Add to Bookmark")
  }

  private var downloadButton: some View {
    Menu {
      downloadMenu
    } label: {
      circleIcon(movieDownloadGlyph)
    }
    .menuIndicator(.hidden)
#if os(macOS)
    .menuStyle(.button)
    .buttonStyle(.plain)
    .fixedSize()
#endif
    .accessibilityLabel("Download")
  }

  @ViewBuilder
  private var playButton: some View {
    let title = (hasResume ? "Continue" : (mediaItem.isSeries ? "Watch" : "Play")).localized
    // On a narrow screen the play button spans the full width on its own row.
    let fullWidth = !usesSidebarSections
    if mediaItem.isSeries, let episode = seriesPlayEpisode {
      NavigationLink(value: itemModel.linkProvider.player(for: episode)) {
        playLabel(title, subtitle: resumeSubtitle, fullWidth: fullWidth)
      }
      .buttonStyle(.plain)
    } else {
      NavigationLink(value: itemModel.linkProvider.player(for: mediaItem)) {
        playLabel(title, subtitle: resumeSubtitle, fullWidth: fullWidth)
      }
      .buttonStyle(.plain)
    }
  }

  // MARK: - Continue ("Netflix-style") resume logic — shared with Home via MediaItem.continueEpisode()

  /// The series episode to continue (shared logic with the Home shelf). Falls back to the local
  /// store so a just-watched episode resumes instantly, before the server refetch lands.
  private var continueTarget: (season: Season, episode: Episode)? {
    mediaItem.continueEpisode() ?? itemModel.localSeriesContinue()
  }

  /// Whether the play button should read "Continue" rather than "Play"/"Watch".
  private var hasResume: Bool {
    if mediaItem.isSeries { return continueTarget != nil }
    let serverTime = mediaItem.videos?.first?.watching.time ?? 0
    let localTime = itemModel.localResumeSeconds(season: nil, episode: mediaItem.videos?.first?.number)
    return serverTime > 0 || localTime > 0
  }

  /// Episode to start for a series: the continue target if any, else the first episode.
  private var seriesPlayEpisode: Episode? {
    if let target = continueTarget {
      return filledEpisode(target.episode, in: target.season)
    }
    return firstPlayableEpisode
  }

  private func playLabel(_ title: String, subtitle: String? = nil, fullWidth: Bool = false) -> some View {
    HStack(spacing: 10) {
      Image(systemName: "play.fill")
      VStack(alignment: .leading, spacing: 1) {
        Text(title).font(.system(size: 16, weight: .semibold))
        if let subtitle {
          Text(subtitle)
            .font(.system(size: 11, weight: .medium))
            .opacity(0.85)
        }
      }
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 22)
    .padding(.vertical, subtitle == nil ? 12 : 8)
    .frame(maxWidth: fullWidth ? .infinity : nil)
    .background(Capsule().fill(Color.KinoPub.accent))
  }

  /// Resume detail shown under "Continue": "S{n} · E{n} · {time}" for series, just time for movies.
  private var resumeSubtitle: String? {
    guard hasResume else { return nil }
    if mediaItem.isSeries, let target = continueTarget {
      let base = "S\(target.season.number) · E\(target.episode.number)"
      let time = max(target.episode.watching.time,
                     itemModel.localResumeSeconds(season: target.season.number, episode: target.episode.number))
      return time > 0 ? "\(base) · \(Self.resumeTime(time))" : base
    }
    let time = max(mediaItem.videos?.first?.watching.time ?? 0,
                   itemModel.localResumeSeconds(season: nil, episode: mediaItem.videos?.first?.number))
    return time > 0 ? Self.resumeTime(time) : nil
  }

  private static func resumeTime(_ seconds: Int) -> String {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
    formatter.unitsStyle = .positional
    formatter.zeroFormattingBehavior = .pad
    return formatter.string(from: TimeInterval(seconds)) ?? ""
  }

  private func circleIcon(_ systemName: String) -> some View {
    Image(systemName: systemName)
      .font(.system(size: 18, weight: .semibold))
      .foregroundStyle(.white)
      .frame(width: 50, height: 50)
      .background(Circle().fill(Color.white.opacity(0.18)))
  }

  /// Download icon glyph for a movie's download button, reflecting the client library state.
  private var movieDownloadGlyph: String {
    guard !mediaItem.isSeries else { return "arrow.down.to.line" }
    switch libraryState.downloadStatus(itemId: mediaItem.id, video: mediaItem.videos?.first?.number, season: nil) {
    case .downloaded: return "arrow.down.circle.fill"
    case .downloading: return "arrow.down.circle"
    case .none: return "arrow.down.to.line"
    }
  }

  /// Small badge on an episode card showing whether it's downloaded or downloading.
  @ViewBuilder
  private func downloadBadge(itemId: Int, video: Int?, season: Int?) -> some View {
    switch libraryState.downloadStatus(itemId: itemId, video: video, season: season) {
    case .downloaded:
      Image(systemName: "arrow.down.circle.fill")
        .font(.system(size: 18))
        .foregroundStyle(.white, Color.KinoPub.accent)
        .padding(8)
    case .downloading:
      ProgressView()
        .controlSize(.small)
        .padding(8)
    case .none:
      EmptyView()
    }
  }

  private func circleIconButton(_ systemName: String,
                                accessibility: String,
                                action: @escaping () -> Void) -> some View {
    Button(action: action) {
      circleIcon(systemName)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibility)
  }

  // MARK: - Download menu (Season ▸ Episode ▸ Quality)

  @ViewBuilder
  private var downloadMenu: some View {
    if mediaItem.isSeries, let seasons = mediaItem.seasons, !seasons.isEmpty {
      ForEach(seasons, id: \.number) { season in
        Menu("\("Season".localized) \(season.number)") {
          seasonDownloadMenu(for: season)
          ForEach(season.episodes, id: \.id) { episode in
            episodeDownloadSubmenu(episode, in: season)
          }
        }
      }
    } else {
      switch libraryState.downloadStatus(itemId: mediaItem.id, video: nil, season: nil) {
      case .downloaded:
        Button { } label: { Label("Downloaded".localized, systemImage: "checkmark.circle.fill") }
          .disabled(true)
      case .downloading:
        Button { } label: { Label("Downloading…".localized, systemImage: "arrow.down.circle") }
          .disabled(true)
      case .none:
        qualityButtons(for: movieDownloadable)
      }
    }
  }

  /// Per-episode entry in the season download menu. Shows the episode name (not just "S1E1") and
  /// disables itself when that episode is already downloaded or downloading.
  @ViewBuilder
  private func episodeDownloadSubmenu(_ episode: Episode, in season: Season) -> some View {
    let title = episodeMenuTitle(episode, in: season)
    switch libraryState.downloadStatus(itemId: mediaItem.id, video: episode.number, season: season.number) {
    case .downloaded:
      Button { } label: { Label(title, systemImage: "checkmark.circle.fill") }.disabled(true)
    case .downloading:
      Button { } label: { Label(title, systemImage: "arrow.down.circle") }.disabled(true)
    case .none:
      Menu(title) { qualityButtons(for: episodeDownloadable(episode, in: season)) }
    }
  }

  /// "S1E1 · Episode name" (or just "S1E1" when the episode has no distinct title).
  private func episodeMenuTitle(_ episode: Episode, in season: Season) -> String {
    let code = "S\(season.number)E\(episode.number)"
    let name = episode.title.trimmingCharacters(in: .whitespaces)
    return name.isEmpty ? code : "\(code) · \(name)"
  }

  /// "Download whole season" entry: one tap per quality (plus a best-available option) that queues
  /// every episode of the season at once.
  @ViewBuilder
  private func seasonDownloadMenu(for season: Season) -> some View {
    let qualities = SeasonDownloadManager.availableQualities(in: season)
    Menu {
      Button("Best quality".localized) {
        itemModel.downloadSeason(season, quality: nil)
      }
      ForEach(qualities, id: \.self) { quality in
        Button(quality) {
          itemModel.downloadSeason(season, quality: quality)
        }
      }
    } label: {
      Label("Download whole season".localized, systemImage: "square.and.arrow.down.on.square")
    }
  }

  private var movieDownloadable: DownloadableMediaItem {
    DownloadableMediaItem(name: mediaItem.title,
                          files: mediaItem.files,
                          mediaItem: mediaItem,
                          watchingMetadata: WatchingMetadata(id: mediaItem.id, video: nil, season: nil))
  }

  private func episodeDownloadable(_ episode: Episode, in season: Season) -> DownloadableMediaItem {
    DownloadableMediaItem(name: "S\(season.number)E\(episode.number)",
                          files: episode.files,
                          mediaItem: mediaItem,
                          watchingMetadata: WatchingMetadata(id: episode.id, video: episode.number, season: season.number))
  }

  @ViewBuilder
  private func qualityButtons(for item: DownloadableMediaItem) -> some View {
    ForEach(item.files.dedupedByQuality) { file in
      Button(file.quality) {
        itemModel.startDownload(item: item, file: file)
      }
    }
  }

  /// Download entry in an episode's context menu. Once an episode is downloaded (or downloading) we
  /// show a disabled status row instead of the quality picker, so it can't be queued twice.
  @ViewBuilder
  private func episodeDownloadMenu(_ episode: Episode, in season: Season) -> some View {
    switch libraryState.downloadStatus(itemId: mediaItem.id, video: episode.number, season: season.number) {
    case .downloaded:
      Button { } label: { Label("Downloaded".localized, systemImage: "checkmark.circle.fill") }
        .disabled(true)
    case .downloading:
      Button { } label: { Label("Downloading…".localized, systemImage: "arrow.down.circle") }
        .disabled(true)
    case .none:
      Menu {
        qualityButtons(for: episodeDownloadable(episode, in: season))
      } label: {
        Label("Download".localized, systemImage: "arrow.down.circle")
      }
    }
  }

  /// Long-press preview for an episode card — the card on a padded background so its rounded corners
  /// (and the text under the thumbnail) aren't clipped by the context-menu lift.
  private func episodePreview(_ episode: Episode, in season: Season) -> some View {
    EpisodeCard(imageURL: episode.thumbnail,
                overline: "\("Episode".localized) \(episode.number)",
                title: episode.fixedTitle,
                footnote: "\(max(episode.duration / 60, 1)) мин",
                progress: episodeProgress(episode, in: season))
      .padding(14)
      .background(Color.KinoPub.background)
  }

  private var firstPlayableEpisode: Episode? {
    guard let season = mediaItem.seasons?.first,
          let episode = season.episodes.first else { return nil }
    episode.seasonNumber = season.number
    episode.mediaId = season.mediaId ?? mediaItem.id
    episode.mediaTitle = mediaItem.localizedTitle
    return episode
  }

  // MARK: - Episodes

  @ViewBuilder
  private var episodesSection: some View {
    if mediaItem.isSeries, let seasons = mediaItem.seasons, !seasons.isEmpty {
      let season = currentSeason(in: seasons)
      VStack(alignment: .leading, spacing: 12) {
        seasonPicker(seasons: seasons, current: season)
        ScrollViewReader { proxy in
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
              ForEach(season.episodes, id: \.id) { episode in
                NavigationLink(value: itemModel.linkProvider.player(for: filledEpisode(episode, in: season))) {
                  EpisodeCard(imageURL: episode.thumbnail,
                              overline: "\("Episode".localized) \(episode.number)",
                              title: episode.fixedTitle,
                              footnote: "\(max(episode.duration / 60, 1)) мин",
                              progress: episodeProgress(episode, in: season))
                  .overlay(alignment: .topTrailing) {
                    if itemModel.isEpisodeWatched(episode) {
                      // Neutral "watched" eye (not the loud accent checkmark).
                      Image(systemName: "eye.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Circle().fill(.black.opacity(0.5)))
                        .padding(8)
                    }
                  }
                  .overlay(alignment: .bottomTrailing) {
                    // Downloads are keyed on the series id (DownloadMeta.id == mediaItem.id), not the
                    // episode id — so the badge must query the series id to actually match.
                    downloadBadge(itemId: mediaItem.id, video: episode.number, season: season.number)
                  }
                }
                .buttonStyle(.plain)
                .id(episode.id)
                .contextMenu {
                  Button {
                    itemModel.toggleEpisodeWatched(episode: episode, season: season.number)
                  } label: {
                    let watched = itemModel.isEpisodeWatched(episode)
                    Label(watched ? "Mark as Unwatched".localized : "Mark as Watched".localized,
                          systemImage: watched ? "eye.fill" : "eye")
                  }
                  episodeDownloadMenu(episode, in: season)
                } preview: {
                  // Custom preview: the default lift clips the card's rounded bottom corners (over the
                  // text). Render the card on its own padded platter so nothing is cut off.
                  episodePreview(episode, in: season)
                }
              }
            }
            .padding(.horizontal, 20)
          }
          // Once the real item loads, jump to the last episode the user watched.
          .onChange(of: itemModel.itemLoaded) { loaded in
            if loaded { scrollToResume(proxy: proxy, seasons: seasons) }
          }
          .onAppear {
            if itemModel.itemLoaded { scrollToResume(proxy: proxy, seasons: seasons) }
          }
        }
      }
    }
  }

  /// The most recently watched (or in-progress) episode across all seasons.
  private func lastWatchedEpisode(in seasons: [Season]) -> (season: Season, episode: Episode)? {
    var best: (season: Season, episode: Episode)?
    for season in seasons {
      for episode in season.episodes where episode.watched > 0 || episode.watching.time > 0 {
        if let current = best {
          if (season.number, episode.number) > (current.season.number, current.episode.number) {
            best = (season, episode)
          }
        } else {
          best = (season, episode)
        }
      }
    }
    return best
  }

  /// Default to the season holding the last watched episode; fall back to the first season.
  private func currentSeason(in seasons: [Season]) -> Season {
    if let number = selectedSeasonNumber, let match = seasons.first(where: { $0.number == number }) {
      return match
    }
    return lastWatchedEpisode(in: seasons)?.season ?? seasons[0]
  }

  private func scrollToResume(proxy: ScrollViewProxy, seasons: [Season]) {
    // Only auto-scroll while showing the auto-selected season (don't fight manual season changes).
    guard selectedSeasonNumber == nil,
          let target = lastWatchedEpisode(in: seasons),
          target.season.number == currentSeason(in: seasons).number else { return }
    withAnimation {
      // Center the current episode horizontally so it's the focus when the series page opens.
      proxy.scrollTo(target.episode.id, anchor: .center)
    }
  }

  @ViewBuilder
  private func seasonPicker(seasons: [Season], current: Season) -> some View {
    if seasons.count > 1 {
      Menu {
        ForEach(seasons) { season in
          Button {
            selectedSeasonNumber = season.number
          } label: {
            if season.number == current.number {
              Label(season.fixedTitle, systemImage: "checkmark")
            } else {
              Text(season.fixedTitle)
            }
          }
        }
      } label: {
        HStack(spacing: 6) {
          Text(current.fixedTitle)
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(Color.KinoPub.text)
          Image(systemName: "chevron.up.chevron.down")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Color.KinoPub.subtitle)
        }
      }
      .padding(.horizontal, 20)
    } else {
      Text(current.fixedTitle)
        .font(.system(size: 22, weight: .bold))
        .foregroundStyle(Color.KinoPub.text)
        .padding(.horizontal, 20)
    }
  }

  private func filledEpisode(_ episode: Episode, in season: Season) -> Episode {
    episode.seasonNumber = season.number
    episode.mediaId = season.mediaId ?? mediaItem.id
    episode.mediaTitle = mediaItem.localizedTitle
    return episode
  }

  private func episodeProgress(_ episode: Episode, in season: Season) -> Double? {
    if itemModel.isEpisodeWatched(episode) { return 1.0 }
    var serverProgress: Double?
    if episode.duration > 0, episode.watching.time > 0 {
      serverProgress = Double(episode.watching.time) / Double(episode.duration)
    }
    // Overlay the local resume point so a just-watched episode shows progress instantly.
    let localProgress = itemModel.localProgressFraction(season: season.number, episode: episode.number)
    guard let best = [serverProgress, localProgress].compactMap({ $0 }).max() else { return nil }
    return min(max(best, 0.02), 1.0)
  }

  // MARK: - Loading skeletons
  // Reserve the same footprint as the real shelf while a dynamically-loaded block is in flight, so it
  // swaps content in place (or collapses once) instead of popping in and shoving the page around.

  private func skeletonPosterShelf(_ title: String) -> some View {
    MediaShelf(title: title, showsChevron: false) {
      ForEach(0..<6, id: \.self) { _ in PosterCard.placeholder() }
    }
  }

  private var skeletonTrailerShelf: some View {
    // Render the real card with no image so the placeholder is exactly the trailer cell's size.
    MediaShelf(title: "Trailers".localized, showsChevron: false) {
      EpisodeCard(imageURL: nil, title: "Trailer")
        .redacted(reason: .placeholder)
    }
  }

  private var skeletonImagesShelf: some View {
    // StillThumbnail with no URL renders its skeleton fill at the exact still size.
    MediaShelf(title: "Images".localized, showsChevron: false) {
      ForEach(0..<6, id: \.self) { _ in StillThumbnail(url: nil) }
    }
  }

  // Approximate the text blocks (heights can't be exact for multi-line copy, but reserving close to
  // the real footprint turns the extras pop-in into a barely-perceptible settle).
  private func skeletonTextSection(_ title: String, rows: Int, rowHeight: CGFloat) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      extrasHeader(title, action: nil)
      VStack(spacing: 10) {
        ForEach(0..<rows, id: \.self) { _ in
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.KinoPub.skeleton)
            .frame(height: rowHeight)
        }
      }
      .padding(.horizontal, 20)
    }
  }

  // MARK: - Trailers

  @ViewBuilder
  private var trailersSection: some View {
    if mediaItem.trailer?.url != nil {
      MediaShelf(title: "Trailers".localized, showsChevron: false) {
        NavigationLink(value: itemModel.linkProvider.trailerPlayer(for: mediaItem)) {
          EpisodeCard(imageURL: mediaItem.posters.big, title: "Trailer")
        }
        .buttonStyle(.plain)
      }
    } else if !itemModel.itemLoaded {
      // Whether a trailer exists is known only once the item loads; hold its place until then.
      skeletonTrailerShelf
    }
  }

  // MARK: - Related

  @ViewBuilder
  private var relatedSection: some View {
    if !itemModel.relatedItems.isEmpty {
      MediaShelf(title: "Related".localized,
                 headerValue: Route.mediaList(itemModel.relatedItems, "Related".localized)) {
        ForEach(itemModel.relatedItems) { item in
          NavigationLink(value: itemModel.linkProvider.link(for: item)) {
            PosterCard(imageURL: item.posters.medium, title: item.localizedTitle)
          }
          .buttonStyle(.plain)
        }
      }
    } else if itemModel.itemLoaded && !itemModel.relatedLoaded {
      skeletonPosterShelf("Related".localized)
    }
  }

  // MARK: - More from director / with actor

  @ViewBuilder
  private func peopleShelf(_ title: String, items: [MediaItem], headerValue: (any Hashable)? = nil) -> some View {
    if !items.isEmpty {
      MediaShelf(title: title, headerValue: headerValue) {
        ForEach(items) { item in
          NavigationLink(value: itemModel.linkProvider.link(for: item)) {
            PosterCard(imageURL: item.posters.medium, title: item.localizedTitle)
              .overlay(alignment: .topTrailing) { MediaCardStatusBadge(item: item) }
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  @ViewBuilder
  private var moreFromDirectorSection: some View {
    if let director = itemModel.primaryDirector {
      if !itemModel.moreFromDirector.isEmpty {
        peopleShelf(String(format: "More from %@".localized, director),
                    items: itemModel.moreFromDirector,
                    headerValue: Route.personSearch(director, "director", director))
      } else if !itemModel.moreFromLoaded {
        skeletonPosterShelf(String(format: "More from %@".localized, director))
      }
    }
  }

  @ViewBuilder
  private var moreWithActorSection: some View {
    if let actor = itemModel.primaryActor {
      if !itemModel.moreWithActor.isEmpty {
        peopleShelf(String(format: "More with %@".localized, actor),
                    items: itemModel.moreWithActor,
                    headerValue: Route.personSearch(actor, "cast", actor))
      } else if !itemModel.moreWithLoaded {
        skeletonPosterShelf(String(format: "More with %@".localized, actor))
      }
    }
  }

  // MARK: - Cast & Crew

  @ViewBuilder
  private var castSection: some View {
    // Prefer the richer Kinopoisk crew (photos + characters + English names) when available,
    // falling back to kino.pub's plain cast/director names.
    if !itemModel.staff.isEmpty {
      staffShelf
    } else {
      castNamesShelf
    }
  }

  private var staffShelf: some View {
    // Lead with a single main director, then the cast — seeing actors matters more than a long list
    // of every director/crew member (the full ordered list stays available in the modal).
    let directors = itemModel.staff.filter { $0.professionKey == "DIRECTOR" }
    let actors = itemModel.staff.filter { $0.professionKey == "ACTOR" }
    let others = itemModel.staff.filter { $0.professionKey != "DIRECTOR" && $0.professionKey != "ACTOR" }
    let ordered = Array(directors.prefix(1)) + actors + others
    let top = Array(ordered.prefix(14))
    return MediaShelf(title: "Cast & Crew".localized,
                      showsChevron: itemModel.staff.count > top.count,
                      onHeaderTap: { showCastCrew = true }) {
      ForEach(top) { member in
        facetLink(staffRoute(member)) {
          CastAvatarView(imageURL: member.posterUrl,
                         name: member.displayName,
                         role: staffRole(member))
        }
      }
    }
  }

  @ViewBuilder
  private var castNamesShelf: some View {
    // Just the main director up front, then the cast (the full director list is in the modal).
    let directors = Array(itemModel.directorNames.prefix(1))
    let allActors = itemModel.castNames
    let actors = Array(allActors.prefix(12))
    let hasMore = allActors.count > actors.count || itemModel.directorNames.count > directors.count
    if !actors.isEmpty || !directors.isEmpty {
      MediaShelf(title: "Cast & Crew".localized,
                 showsChevron: hasMore,
                 onHeaderTap: hasMore ? { showCastCrew = true } : nil) {
        ForEach(directors, id: \.self) { name in
          facetLink(itemModel.directorRoute(name)) {
            CastAvatarView(imageURL: ActorImageProvider.photoURLString(for: name),
                           name: name, role: "Director".localized)
          }
        }
        ForEach(actors, id: \.self) { name in
          facetLink(itemModel.actorRoute(name)) {
            CastAvatarView(imageURL: ActorImageProvider.photoURLString(for: name),
                           name: name, role: "Actor".localized)
          }
        }
      }
    }
  }

  /// For an actor show the character (`description`); for crew show the profession.
  private func staffRole(_ member: KpStaffMember) -> String? {
    let character = member.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !character.isEmpty { return character }
    return member.professionText
  }

  private func staffRoute(_ member: KpStaffMember) -> (any Hashable)? {
    member.professionKey == "DIRECTOR"
      ? itemModel.directorRoute(member.displayName)
      : itemModel.actorRoute(member.displayName)
  }

  // MARK: - Kinopoisk extras (stills / facts / reviews)

  /// A titled vertical section header with an optional "see all" chevron, matching the shelf headers.
  private func extrasHeader(_ title: String, action: (() -> Void)?) -> some View {
    Button(action: { action?() }) {
      HStack(spacing: 6) {
        Text(title)
          .font(.system(size: 22, weight: .bold))
          .foregroundStyle(Color.KinoPub.text)
        if action != nil {
          Image(systemName: "chevron.right")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Color.KinoPub.subtitle)
        }
        Spacer(minLength: 0)
      }
      .contentShape(Rectangle())
      .padding(.horizontal, 20)
    }
    .buttonStyle(.plain)
    .disabled(action == nil)
  }

  @ViewBuilder
  private var imagesSection: some View {
    if !itemModel.images.isEmpty {
      let preview = Array(itemModel.images.prefix(15))
      let hasMore = itemModel.images.count > preview.count
      MediaShelf(title: "Images".localized,
                 showsChevron: hasMore,
                 onHeaderTap: hasMore ? { stillSelection = StillSelection(index: 0) } : nil) {
        ForEach(Array(preview.enumerated()), id: \.offset) { idx, image in
          Button { stillSelection = StillSelection(index: idx) } label: {
            StillThumbnail(url: image.previewUrl ?? image.imageUrl)
          }
          .buttonStyle(.plain)
        }
      }
    } else if itemModel.itemLoaded && !itemModel.extrasLoaded {
      skeletonImagesShelf
    }
  }

  @ViewBuilder
  private var factsSection: some View {
    if !itemModel.facts.isEmpty {
      VStack(alignment: .leading, spacing: 14) {
        extrasHeader("Facts".localized, action: itemModel.facts.count > 3 ? { showFacts = true } : nil)
        VStack(spacing: 10) {
          ForEach(itemModel.facts.prefix(3)) { fact in
            FactCard(fact: fact)
          }
        }
        .padding(.horizontal, 20)
      }
    } else if itemModel.itemLoaded && !itemModel.extrasLoaded {
      skeletonTextSection("Facts".localized, rows: 3, rowHeight: 56)
    }
  }

  @ViewBuilder
  private var reviewsSection: some View {
    if !itemModel.reviews.items.isEmpty {
      VStack(alignment: .leading, spacing: 14) {
        extrasHeader("Reviews".localized, action: itemModel.reviews.items.count > 2 ? { showReviews = true } : nil)
        VStack(spacing: 10) {
          ForEach(itemModel.reviews.items.prefix(2)) { review in
            ReviewCard(review: review)
          }
        }
        .padding(.horizontal, 20)
      }
    } else if itemModel.itemLoaded && !itemModel.extrasLoaded {
      skeletonTextSection("Reviews".localized, rows: 2, rowHeight: 110)
    }
  }

  // MARK: - Comments

  @ViewBuilder
  private var commentsSection: some View {
    if FeatureFlags.comments, !isSkeleton {
      Button {
        showComments = true
      } label: {
        HStack(spacing: 12) {
          Image(systemName: "bubble.left.and.bubble.right.fill")
            .font(.system(size: 18))
            .foregroundStyle(Color.KinoPub.accent)
          Text("Comments".localized)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.KinoPub.text)
          Spacer()
          Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.KinoPub.subtitle)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.06))
        )
        .padding(.horizontal, 20)
      }
      .buttonStyle(.plain)
    }
  }

  // MARK: - Description

  @ViewBuilder
  private var descriptionSection: some View {
    if !mediaItem.plot.isEmpty {
      VStack(alignment: .leading, spacing: 10) {
        Text("Description")
          .font(.system(size: 22, weight: .bold))
          .foregroundStyle(Color.KinoPub.text)
        genreChips
        Text(mediaItem.plot)
          .font(.system(size: 14))
          .foregroundStyle(Color.KinoPub.text)
          .multilineTextAlignment(.leading)
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(Color.white.opacity(0.06))
      )
      .padding(.horizontal, 20)
    }
  }

  /// Tappable genre chips. Each opens a catalog filtered by that genre, scoped
  /// to this item's own content type (a serial's genre opens serials, etc.).
  @ViewBuilder
  private var genreChips: some View {
    let genres = mediaItem.genres.filter { ($0.title?.isEmpty == false) }
    if !genres.isEmpty {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(genres, id: \.id) { genre in
            sectionFacet(filter: itemModel.genreFilter(id: genre.id),
                         route: itemModel.genreRoute(id: genre.id, title: genre.title ?? "")) {
              chip(genre.title?.uppercased() ?? "")
            }
          }
        }
      }
    }
  }

  private func chip(_ text: String) -> some View {
    Text(text)
      .font(.system(size: 12, weight: .semibold))
      .foregroundStyle(Color.KinoPub.accent)
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(
        Capsule().fill(Color.KinoPub.accent.opacity(0.15))
      )
  }

  // MARK: - Information & Languages

  private var infoSection: some View {
    MediaItemInfoSection(mediaItem: mediaItem,
                         itemModel: itemModel,
                         usesSidebar: usesSidebarSections,
                         openSection: { filter in
                           navigationState.pendingCategoryFilter = filter
                           navigationState.sidebarSelection = .category(filter.contentType)
                         })
      .padding(.horizontal, 20)
  }
}

// MARK: - Information & Languages

/// Apple TV-style "Information" + "Languages" block. Prefers a two-column
/// layout and falls back to a stacked one when too narrow. Preserves the
/// IMDB / Kinopoisk deep links (issue #44).
private struct MediaItemInfoSection: View {

  let mediaItem: MediaItem
  @ObservedObject var itemModel: MediaItemModel
  let usesSidebar: Bool
  let openSection: (MediaItemsFilter) -> Void

  /// A tappable facet that deep-links into a section (wide) or pushes a filtered catalog (compact).
  @ViewBuilder
  private func sectionFacet<Label: View>(filter: MediaItemsFilter,
                                         route: (any Hashable)?,
                                         @ViewBuilder label: () -> Label) -> some View {
    if usesSidebar {
      Button { openSection(filter) } label: { label() }
        .buttonStyle(.plain)
    } else {
      facetLink(route, label: label)
    }
  }

  var body: some View {
    // Prefer a two-column layout, but fall back to a stacked layout when the
    // available width is too narrow to fit both columns comfortably.
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .top, spacing: 48) {
        information
        languages
        Spacer(minLength: 0)
      }
      VStack(alignment: .leading, spacing: 24) {
        information
        languages
      }
    }
  }

  // MARK: - Information

  private var information: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionTitle("Information".localized)

      if mediaItem.year > 0 {
        facetRow(label: "Premiere".localized,
                 value: "\(mediaItem.year)",
                 filter: itemModel.yearFilter(mediaItem.year),
                 route: itemModel.yearRoute(mediaItem.year))
      }

      if !mediaItem.countries.isEmpty {
        VStack(alignment: .leading, spacing: 2) {
          Text("Country".localized.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.KinoPub.subtitle)
          FlowLayout(spacing: 10, lineSpacing: 6) {
            ForEach(Array(mediaItem.countries.enumerated()), id: \.offset) { _, country in
              sectionFacet(filter: itemModel.countryFilter(id: country.id),
                           route: itemModel.countryRoute(id: country.id, title: country.title)) {
                facetValueText(country.title, isLink: true)
              }
            }
          }
        }
      }

      if !itemModel.directorNames.isEmpty {
        VStack(alignment: .leading, spacing: 2) {
          Text("Director".localized.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.KinoPub.subtitle)
          FlowLayout(spacing: 10, lineSpacing: 6) {
            ForEach(Array(itemModel.directorNames.enumerated()), id: \.offset) { _, name in
              facetLink(itemModel.directorRoute(name)) {
                facetValueText(name, isLink: itemModel.directorRoute(name) != nil)
              }
            }
          }
        }
      }

      if (mediaItem.imdbRating ?? 0) > 0 || (mediaItem.kinopoiskRating ?? 0) > 0 || (kinopubScore ?? 0) > 0 {
        VStack(alignment: .leading, spacing: 4) {
          Text("Rating".localized.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.KinoPub.subtitle)
          RatingsDetailRow(kinopubScore: kinopubScore,
                           kinopubVotes: mediaItem.ratingVotes,
                           imdbScore: mediaItem.imdbRating,
                           imdbVotes: mediaItem.imdbVotes,
                           kinopoiskScore: mediaItem.kinopoiskRating,
                           kinopoiskVotes: mediaItem.kinopoiskVotes)
        }
      }

      if mediaItem.isSeries {
        infoRow(label: "Status".localized, value: statusValue)
        if let total = totalValue {
          infoRow(label: "Total".localized, value: total)
        }
        infoRow(label: "Duration".localized, value: durationValue)
      }
    }
  }

  // MARK: - Series info helpers

  private var statusValue: String {
    mediaItem.finished ? "Finished".localized : "Ongoing".localized
  }

  private var totalValue: String? {
    guard let seasons = mediaItem.seasons, !seasons.isEmpty else { return nil }
    let episodes = seasons.reduce(0) { $0 + $1.episodes.count }
    return "\(seasons.count) \("seasons".localized), \(episodes) \("episodes".localized)"
  }

  private var durationValue: String {
    let average = mediaItem.duration.average
    let total = mediaItem.duration.total
    var parts: [String] = []
    if average > 0 {
      let minutes = Int(average / 60)
      parts.append("≈ \(MediaItemInfoSection.clock(average)) (\(minutes) \("min".localized))")
    }
    if total > 0 {
      parts.append("\("total".localized): \(MediaItemInfoSection.abbreviated(total))")
    }
    return parts.joined(separator: ", ")
  }

  private static func clock(_ seconds: Double) -> String {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute, .second]
    formatter.unitsStyle = .positional
    formatter.zeroFormattingBehavior = .pad
    return formatter.string(from: seconds) ?? ""
  }

  private static func abbreviated(_ seconds: Double) -> String {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.day, .hour, .minute]
    formatter.unitsStyle = .abbreviated
    return formatter.string(from: seconds) ?? ""
  }

  // MARK: - Languages

  @ViewBuilder
  private var languages: some View {
    let voice = mediaItem.voice?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !voice.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        sectionTitle("Languages".localized)
        infoRow(label: "Audio", value: voice)
      }
    }
  }

  // MARK: - Building blocks

  private func sectionTitle(_ text: String) -> some View {
    Text(text)
      .font(.system(size: 22, weight: .bold))
      .foregroundStyle(Color.KinoPub.text)
  }

  private func infoRow(label: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label.uppercased())
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(Color.KinoPub.subtitle)
      Text(value)
        .font(.system(size: 14))
        .foregroundStyle(Color.KinoPub.text)
    }
  }

  /// An info row whose value is tappable (when a `route` exists) to open a
  /// filtered catalog (e.g. year).
  @ViewBuilder
  private func facetRow(label: String, value: String, filter: MediaItemsFilter? = nil, route: (any Hashable)?) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label.uppercased())
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(Color.KinoPub.subtitle)
      if let filter {
        sectionFacet(filter: filter, route: route) {
          facetValueText(value, isLink: route != nil)
        }
      } else {
        facetLink(route) {
          facetValueText(value, isLink: route != nil)
        }
      }
    }
  }

  @ViewBuilder
  private func facetLink<Label: View>(_ route: (any Hashable)?, @ViewBuilder label: () -> Label) -> some View {
    if let route {
      NavigationLink(value: route) {
        label()
      }
      .buttonStyle(.plain)
    } else {
      label()
    }
  }

  private func facetValueText(_ value: String, isLink: Bool) -> some View {
    Text(value)
      .font(.system(size: 14, weight: isLink ? .semibold : .regular))
      .foregroundStyle(isLink ? Color.KinoPub.accent : Color.KinoPub.text)
  }

  @ViewBuilder
  private func ratingRow(label: String, value: String, url: URL?) -> some View {
    if let url {
      Link(destination: url) {
        ratingContent(label: label, value: value, isLink: true)
      }
      .buttonStyle(.plain)
    } else {
      ratingContent(label: label, value: value, isLink: false)
    }
  }

  private func ratingContent(label: String, value: String, isLink: Bool) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label.uppercased())
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(Color.KinoPub.subtitle)
      HStack(spacing: 6) {
        Text(value)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(isLink ? Color.KinoPub.accent : Color.KinoPub.text)
        if isLink {
          Image(systemName: "arrow.up.right")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.KinoPub.accent)
        }
      }
    }
  }

  // MARK: - Deep links (issue #44)

  /// kino.pub's own rating on a 0–10 scale (the API gives it as a 0–100 percentage). nil when unrated.
  private var kinopubScore: Double? {
    mediaItem.ratingPercentage > 0 ? mediaItem.ratingPercentage / 10.0 : nil
  }

  private var imdbURL: URL? {
    guard let imdb = mediaItem.imdb, imdb > 0 else { return nil }
    return URL(string: "https://www.imdb.com/title/tt\(String(format: "%07d", imdb))/")
  }

  private var kinopoiskURL: URL? {
    guard let kinopoisk = mediaItem.kinopoisk, kinopoisk > 0 else { return nil }
    return URL(string: "https://www.kinopoisk.ru/film/\(kinopoisk)/")
  }
}

/// Full "Cast & Crew" roster, shown when the user taps the shelf header. Apple-TV-style grouped grid
/// of circular avatars. Prefers the Kinopoisk crew (photos + characters, grouped by profession);
/// falls back to kino.pub's plain director/actor names with CDN photos.
struct CastCrewView: View {
  let directors: [String]
  let actors: [String]
  let staff: [KpStaffMember]
  /// Called when a person is tapped: (name, field) where field is "cast" or "director". The view
  /// dismisses itself first, then the presenter opens that person's section (like More with / More from).
  var onSelect: ((_ name: String, _ field: String) -> Void)?
  @Environment(\.dismiss) private var dismiss

  private let columns = [GridItem(.adaptive(minimum: 100), spacing: 14, alignment: .top)]

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 28) {
          if !staff.isEmpty {
            staffContent
          } else {
            if !directors.isEmpty { namesSection(title: "Directors".localized, names: directors, field: "director") }
            if !actors.isEmpty { namesSection(title: "Cast".localized, names: actors, field: "cast") }
          }
        }
        .padding(.vertical, 16)
      }
      .background(Color.KinoPub.background)
      .navigationTitle("Cast & Crew".localized)
#if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
#endif
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done".localized) { dismiss() }
        }
      }
    }
  }

  /// Kinopoisk crew grouped by profession ("Режиссёры", "Актёры", …), preserving the API order.
  @ViewBuilder
  private var staffContent: some View {
    let groups = orderedProfessionGroups
    ForEach(groups, id: \.0) { profession, members in
      VStack(alignment: .leading, spacing: 14) {
        sectionTitle(profession)
        LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
          ForEach(members) { member in
            personButton(name: member.displayName,
                         field: member.professionKey == "DIRECTOR" ? "director" : "cast") {
              CastAvatarView(imageURL: member.posterUrl,
                             name: member.displayName,
                             role: member.description?.isEmpty == false ? member.description : nil,
                             diameter: 80)
            }
          }
        }
        .padding(.horizontal, 20)
      }
    }
  }

  /// Wraps a person avatar so tapping it dismisses the modal and opens that person's section.
  @ViewBuilder
  private func personButton<Label: View>(name: String, field: String, @ViewBuilder label: () -> Label) -> some View {
    Button {
      onSelect?(name, field)
      dismiss()
    } label: {
      label()
    }
    .buttonStyle(.plain)
  }

  private var orderedProfessionGroups: [(String, [KpStaffMember])] {
    var order: [String] = []
    var map: [String: [KpStaffMember]] = [:]
    for member in staff {
      let key = (member.professionText ?? "—")
      if map[key] == nil { order.append(key) }
      map[key, default: []].append(member)
    }
    return order.map { ($0, map[$0] ?? []) }
  }

  @ViewBuilder
  private func namesSection(title: String, names: [String], field: String) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      sectionTitle(title)
      LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
        ForEach(names, id: \.self) { name in
          personButton(name: name, field: field) {
            CastAvatarView(imageURL: ActorImageProvider.photoURLString(for: name),
                           name: name, diameter: 80)
          }
        }
      }
      .padding(.horizontal, 20)
    }
  }

  private func sectionTitle(_ text: String) -> some View {
    Text(text)
      .font(.system(size: 20, weight: .bold))
      .foregroundStyle(Color.KinoPub.text)
      .padding(.horizontal, 20)
  }
}

// MARK: - Kinopoisk extras: components & sheets

/// Identifiable wrapper so the stills viewer can be presented via `.sheet(item:)`.
struct StillSelection: Identifiable {
  let index: Int
  var id: Int { index }
}

/// A 16:9 still thumbnail for the Images shelf.
struct StillThumbnail: View {
  let url: String?
  var body: some View {
    Color.KinoPub.skeleton
      .frame(width: 200, height: 112)
      .overlay {
        CachedAsyncImage(url: URL(string: url ?? "")) { image in
          image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
          Color.KinoPub.skeleton
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
  }
}

/// A single trivia fact / goof card. The icon is chosen from trigger words in the text (money, awards,
/// camera, cast, music, …) and sits in a tinted rounded square — iOS Settings / App Store style.
struct FactCard: View {
  let fact: KpFact

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      let glyph = FactGlyph.for(fact)
      Image(systemName: glyph.symbol)
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(glyph.color.opacity(0.85))
        .frame(width: 22, alignment: .center)
        .padding(.top, 1)
      Text(KinopoiskText.plain(fact.text))
        .font(.system(size: 14))
        .foregroundStyle(Color.KinoPub.text)
        .lineSpacing(2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
    }
    .padding(14)
    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.KinoPub.selectionBackground))
  }
}

/// Maps a fact's text to a tasteful SF Symbol + tint by scanning for trigger words (Russian + a few
/// English). First match wins, so the list is ordered most-specific → general.
enum FactGlyph {
  static func `for`(_ fact: KpFact) -> (symbol: String, color: Color) {
    let text = fact.text.lowercased()
    func has(_ words: [String]) -> Bool { words.contains { text.contains($0) } }

    if fact.isBlooper { return ("exclamationmark.bubble.fill", Color(red: 0.45, green: 0.48, blue: 0.55)) }
    if has(["оскар", "преми", "награ", "номина", "глобус", "канн", "бафта", "пальм"]) {
      return ("trophy.fill", Color(red: 0.84, green: 0.66, blue: 0.16))
    }
    if has(["бюджет", "млн", "миллион", "миллиард", "доллар", "гонорар", "сбор", "касс", "$", "заработа", "стои"]) {
      return ("dollarsign.circle.fill", Color(red: 0.20, green: 0.70, blue: 0.42))
    }
    if has(["роль", "сыгра", "актёр", "актер", "актрис", "кастинг", "пробы", "дублёр", "дублер", "каскадёр", "каскадер", "сниматься"]) {
      return ("theatermasks.fill", Color(red: 0.56, green: 0.36, blue: 0.80))
    }
    if has(["режиссёр", "режиссер", "постанов", "снял фильм", "снимать фильм"]) {
      return ("megaphone.fill", Color(red: 0.95, green: 0.56, blue: 0.20))
    }
    if has(["камер", "плёнк", "пленк", "imax", "кадр", "съёмк", "съемк", "оператор", "объектив", "снима"]) {
      return ("camera.fill", Color(red: 0.20, green: 0.55, blue: 0.92))
    }
    if has(["музык", "саундтрек", "композитор", "песн", "мелоди", "звук"]) {
      return ("music.note", Color(red: 0.92, green: 0.36, blue: 0.56))
    }
    if has(["книг", "сценари", "роман", "основан на", "по мотивам", "автор"]) {
      return ("book.fill", Color(red: 0.30, green: 0.62, blue: 0.60))
    }
    if has(["компьютер", "cgi", "эффект", "график", "грим", "технолог", "взрыв"]) {
      return ("wand.and.stars", Color(red: 0.38, green: 0.42, blue: 0.86))
    }
    if has(["травм", "погиб", "опасн", "ранен", "несчаст", "пострада"]) {
      return ("exclamationmark.triangle.fill", Color(red: 0.88, green: 0.32, blue: 0.32))
    }
    if has(["впервые", "рекорд", "первый", "единствен", "самый"]) {
      return ("star.fill", Color(red: 0.95, green: 0.74, blue: 0.20))
    }
    if has(["язык", "перевод", "дубляж", "стран"]) {
      return ("globe", Color(red: 0.18, green: 0.66, blue: 0.66))
    }
    if has(["час", "минут", "год", " лет", "длил", "снимал"]) {
      return ("clock.fill", Color(red: 0.42, green: 0.52, blue: 0.64))
    }
    return ("lightbulb.fill", Color(red: 0.95, green: 0.66, blue: 0.18))
  }
}

/// A review card with an editorial serif body, clamped to 4 lines and expandable in place.
struct ReviewCard: View {
  let review: KpReview
  @State private var expanded = false

  private var bodyText: String { KinopoiskText.plain(review.description ?? "") }
  /// Kinopoisk reviews are long-form; show the expand toggle when the body clearly exceeds ~4 lines.
  private var isExpandable: Bool { bodyText.count > 220 }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      // Sentiment dot + author + date.
      HStack(spacing: 7) {
        Circle().fill(typeColor).frame(width: 7, height: 7)
        Text(review.author ?? "Аноним".localized)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(Color.KinoPub.text)
          .lineLimit(1)
        if let date = formattedDate {
          Text("·").font(.system(size: 12)).foregroundStyle(Color.KinoPub.subtitle)
          Text(date).font(.system(size: 12)).foregroundStyle(Color.KinoPub.subtitle)
        }
        Spacer(minLength: 0)
      }

      if let title = review.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
        Text(title)
          .font(.system(.headline, design: .serif).weight(.semibold))
          .foregroundStyle(Color.KinoPub.text)
          .lineLimit(2)
          .multilineTextAlignment(.leading)
      }

      Text(bodyText)
        .font(.system(.subheadline, design: .serif))
        .foregroundStyle(Color.KinoPub.text.opacity(0.92))
        .lineSpacing(3)
        .lineLimit(expanded ? nil : 4)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)

      if isExpandable {
        Button(expanded ? "Show less".localized : "Show more".localized) {
          withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Color.KinoPub.accent)
        .buttonStyle(.plain)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.KinoPub.selectionBackground))
  }

  private var typeColor: Color {
    switch (review.type ?? "").uppercased() {
    case "POSITIVE": return Color(red: 0.30, green: 0.78, blue: 0.45)
    case "NEGATIVE": return Color(red: 0.90, green: 0.36, blue: 0.36)
    default: return Color.KinoPub.subtitle
    }
  }

  private var formattedDate: String? {
    guard let raw = review.date, !raw.isEmpty else { return nil }
    let parser = DateFormatter()
    parser.locale = Locale(identifier: "en_US_POSIX")
    parser.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    guard let date = parser.date(from: raw) else { return nil }
    let out = DateFormatter()
    out.dateStyle = .long
    out.timeStyle = .none
    return out.string(from: date)
  }
}

/// Full Facts sheet.
struct FactsView: View {
  let facts: [KpFact]
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 10) {
          ForEach(facts) { FactCard(fact: $0) }
        }
        .padding(16)
      }
      .background(Color.KinoPub.background)
      .navigationTitle("Facts".localized)
#if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
#endif
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done".localized) { dismiss() } } }
    }
  }
}

/// Full Reviews sheet.
struct ReviewsView: View {
  let reviews: KpReviewsPage
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 12) {
          ForEach(reviews.items) { review in
            ReviewCard(review: review)
          }
        }
        .padding(16)
      }
      .background(Color.KinoPub.background)
      .navigationTitle("Reviews".localized)
#if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
#endif
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done".localized) { dismiss() } } }
    }
  }
}

/// Full-screen swipeable stills viewer.
struct StillsViewer: View {
  let images: [KpImage]
  let startIndex: Int
  @Environment(\.dismiss) private var dismiss
  @State private var index: Int

  init(images: [KpImage], startIndex: Int) {
    self.images = images
    self.startIndex = startIndex
    _index = State(initialValue: startIndex)
  }

  var body: some View {
    NavigationStack {
      TabView(selection: $index) {
        ForEach(Array(images.enumerated()), id: \.offset) { i, image in
          CachedAsyncImage(url: URL(string: image.imageUrl ?? image.previewUrl ?? "")) { img in
            img.resizable().aspectRatio(contentMode: .fit)
          } placeholder: {
            ProgressView()
          }
          .tag(i)
        }
      }
#if os(iOS)
      .tabViewStyle(.page(indexDisplayMode: .automatic))
#endif
      .background(Color.black.ignoresSafeArea())
      .navigationTitle("\(min(index + 1, images.count)) / \(images.count)")
#if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
#endif
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done".localized) { dismiss() } } }
    }
  }
}

/// Light HTML→plain-text cleanup for Kinopoisk facts / review bodies (tags + named & numeric entities).
enum KinopoiskText {
  static func plain(_ html: String) -> String {
    var s = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
    let entities = ["&nbsp;": " ", "&mdash;": "—", "&ndash;": "–", "&laquo;": "«", "&raquo;": "»",
                    "&quot;": "\"", "&hellip;": "…", "&amp;": "&", "&lt;": "<", "&gt;": ">",
                    "&rsquo;": "’", "&lsquo;": "‘", "&ldquo;": "“", "&rdquo;": "”"]
    for (k, v) in entities { s = s.replacingOccurrences(of: k, with: v) }
    s = decodeNumericEntities(s)
    s = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    return s.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Replace decimal (`&#171;`) and hex (`&#xAB;`) HTML character references with their characters.
  private static func decodeNumericEntities(_ s: String) -> String {
    guard s.contains("&#"), let regex = try? NSRegularExpression(pattern: "&#(x?)([0-9a-fA-F]+);") else { return s }
    let ns = s as NSString
    let matches = regex.matches(in: s, range: NSRange(location: 0, length: ns.length))
    guard !matches.isEmpty else { return s }
    var result = ""
    var cursor = 0
    for m in matches {
      result += ns.substring(with: NSRange(location: cursor, length: m.range.location - cursor))
      let isHex = !ns.substring(with: m.range(at: 1)).isEmpty
      let digits = ns.substring(with: m.range(at: 2))
      if let code = UInt32(digits, radix: isHex ? 16 : 10), let scalar = Unicode.Scalar(code) {
        result.unicodeScalars.append(scalar)
      } else {
        result += ns.substring(with: m.range)  // malformed — leave untouched
      }
      cursor = m.range.location + m.range.length
    }
    result += ns.substring(from: cursor)
    return result
  }
}

struct MediaItemView_Previews: PreviewProvider {
  struct Preview: View {
    var body: some View {
      MediaItemView(model: MediaItemModel(mediaItemId: MediaItem.mock().id,
                                          itemsService: VideoContentServiceMock(),
                                          downloadManager: DownloadManager<DownloadMeta>(fileSaver: FileSaver(),
                                                                                      database: DownloadedFilesDatabase<DownloadMeta>(fileSaver: FileSaver())),
                                          linkProvider: RouteLinkProvider(),
                                          errorHandler: ErrorHandler()))
    }
  }
  static var previews: some View {
    NavigationStack {
      Preview()
    }
  }
}
