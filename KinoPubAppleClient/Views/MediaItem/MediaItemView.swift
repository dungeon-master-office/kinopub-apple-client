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
        relatedSection
        castSection
        descriptionSection
        infoSection
        commentsSection
      }
      .padding(.bottom, 32)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(Color.KinoPub.background)
    // Let the hero cover bleed up under the (transparent) navigation bar.
    .ignoresSafeArea(edges: .top)
    .sheet(isPresented: $showComments) {
      CommentsView(mediaId: mediaItem.id)
    }
    .toast(message: $itemModel.toastMessage)
    #if os(iOS)
    .toolbar(.hidden, for: .tabBar)
    .toolbarBackground(.hidden, for: .navigationBar)
    .toolbarColorScheme(.dark, for: .navigationBar)
    #endif
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
        Task { await itemModel.loadCastPhotos() }
      }
    }
    .handleError(state: $errorHandler.state)
  }

  // MARK: - Hero

  private var hero: some View {
    HeroBackdrop(imageURL: mediaItem.posters.wide ?? mediaItem.posters.big, height: 460, tallBlur: true, blurReduction: 50) {
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

        // Reuse the КП / IMDb badges from the tiles in the hero (no background pill here).
        ContentItemRatingView(imdbScore: mediaItem.imdbRating,
                              kinopoiskScore: mediaItem.kinopoiskRating,
                              showsBackground: false)

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
    if mediaItem.trailer?.url != nil {
      NavigationLink(value: itemModel.linkProvider.trailerPlayer(for: mediaItem)) {
        circleIcon("film")
      }
      #if os(macOS)
      .buttonStyle(.plain)
      #endif
      .accessibilityLabel("Trailer")
    }
  }

  private var watchlistButton: some View {
    // Optimistic client state first, server flag as the fallback.
    let inWatchlist = libraryState.inWatchlist(itemId: mediaItem.id) ?? (mediaItem.inWatchlist == true)
    return circleIconButton(inWatchlist ? "checkmark" : "plus",
                            accessibility: inWatchlist ? "Remove from Watchlist" : "Add to Watchlist") {
      itemModel.toggleWatchlist()
    }
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
    if !libraryState.bookmarkFolders.isEmpty {
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
      } label: {
        // Fill the icon when the item is in at least one folder.
        circleIcon(libraryState.isInAnyBookmarkFolder(itemId: mediaItem.id) ? "folder.fill" : "folder")
      }
      #if os(macOS)
      .menuStyle(.borderlessButton)
      .fixedSize()
      #endif
      .accessibilityLabel("Add to Bookmark")
    }
  }

  private var downloadButton: some View {
    Menu {
      downloadMenu
    } label: {
      circleIcon(movieDownloadGlyph)
    }
    .menuIndicator(.hidden)
#if os(macOS)
    .menuStyle(.borderlessButton)
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
      #if os(macOS)
      .buttonStyle(.plain)
      #endif
    } else {
      NavigationLink(value: itemModel.linkProvider.player(for: mediaItem)) {
        playLabel(title, subtitle: resumeSubtitle, fullWidth: fullWidth)
      }
      #if os(macOS)
      .buttonStyle(.plain)
      #endif
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
    #if os(macOS)
    .buttonStyle(.plain)
    #endif
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
            Menu("S\(season.number)E\(episode.number)") {
              qualityButtons(for: episodeDownloadable(episode, in: season))
            }
          }
        }
      }
    } else {
      qualityButtons(for: movieDownloadable)
    }
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
    ForEach(item.files) { file in
      Button(file.quality) {
        itemModel.startDownload(item: item, file: file)
      }
    }
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
                      Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white, Color.KinoPub.accent)
                        .padding(8)
                    }
                  }
                  .overlay(alignment: .bottomTrailing) {
                    downloadBadge(itemId: episode.id, video: episode.number, season: season.number)
                  }
                }
                #if os(macOS)
                .buttonStyle(.plain)
                #endif
                .id(episode.id)
                .contextMenu {
                  Button {
                    itemModel.toggleEpisodeWatched(episode: episode, season: season.number)
                  } label: {
                    let watched = itemModel.isEpisodeWatched(episode)
                    Label(watched ? "Mark as Unwatched".localized : "Mark as Watched".localized,
                          systemImage: watched ? "checkmark.circle" : "circle")
                  }
                  Menu {
                    qualityButtons(for: episodeDownloadable(episode, in: season))
                  } label: {
                    Label("Download".localized, systemImage: "arrow.down.circle")
                  }
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
      proxy.scrollTo(target.episode.id, anchor: .leading)
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

  // MARK: - Trailers

  @ViewBuilder
  private var trailersSection: some View {
    if mediaItem.trailer?.url != nil {
      MediaShelf(title: "Trailers".localized, showsChevron: false) {
        NavigationLink(value: itemModel.linkProvider.trailerPlayer(for: mediaItem)) {
          EpisodeCard(imageURL: mediaItem.posters.big, title: "Trailer")
        }
        #if os(macOS)
        .buttonStyle(.plain)
        #endif
      }
    }
  }

  // MARK: - Related

  @ViewBuilder
  private var relatedSection: some View {
    if !itemModel.relatedItems.isEmpty {
      MediaShelf(title: "Related".localized, showsChevron: false) {
        ForEach(itemModel.relatedItems) { item in
          NavigationLink(value: itemModel.linkProvider.link(for: item)) {
            PosterCard(imageURL: item.posters.medium, title: item.localizedTitle)
          }
          #if os(macOS)
          .buttonStyle(.plain)
          #endif
        }
      }
    }
  }

  // MARK: - Cast & Crew

  @ViewBuilder
  private var castSection: some View {
    let actors = Array(itemModel.castNames.prefix(12))
    let directors = mediaItem.director
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    if !actors.isEmpty || !directors.isEmpty {
      MediaShelf(title: "Cast & Crew".localized, showsChevron: false) {
        ForEach(directors, id: \.self) { name in
          facetLink(itemModel.directorRoute(name)) {
            CastAvatarView(imageURL: itemModel.personImages[name]?.absoluteString,
                           name: name, role: "Director".localized)
          }
        }
        ForEach(actors, id: \.self) { name in
          facetLink(itemModel.actorRoute(name)) {
            CastAvatarView(imageURL: itemModel.personImages[name]?.absoluteString,
                           name: name, role: "Actor".localized)
          }
        }
      }
    }
  }

  // MARK: - Comments

  @ViewBuilder
  private var commentsSection: some View {
    if !isSkeleton {
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
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
              ForEach(Array(mediaItem.countries.enumerated()), id: \.offset) { _, country in
                sectionFacet(filter: itemModel.countryFilter(id: country.id),
                             route: itemModel.countryRoute(id: country.id, title: country.title)) {
                  facetValueText(country.title, isLink: true)
                }
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
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
              ForEach(Array(itemModel.directorNames.enumerated()), id: \.offset) { index, name in
                if index > 0 {
                  Text("•")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.KinoPub.subtitle)
                }
                facetLink(itemModel.directorRoute(name)) {
                  facetValueText(name, isLink: itemModel.directorRoute(name) != nil)
                }
              }
            }
          }
        }
      }

      if (mediaItem.imdbRating ?? 0) > 0 || (mediaItem.kinopoiskRating ?? 0) > 0 {
        VStack(alignment: .leading, spacing: 4) {
          Text("Rating".localized.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.KinoPub.subtitle)
          RatingsDetailRow(imdbScore: mediaItem.imdbRating,
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
      #if os(macOS)
      .buttonStyle(.plain)
      #endif
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

  private var imdbURL: URL? {
    guard let imdb = mediaItem.imdb, imdb > 0 else { return nil }
    return URL(string: "https://www.imdb.com/title/tt\(String(format: "%07d", imdb))/")
  }

  private var kinopoiskURL: URL? {
    guard let kinopoisk = mediaItem.kinopoisk, kinopoisk > 0 else { return nil }
    return URL(string: "https://www.kinopoisk.ru/film/\(kinopoisk)/")
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
