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
  @Environment(\.appContext) private var appContext
#if os(iOS)
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif
  @StateObject private var itemModel: MediaItemModel

  @State private var plotExpanded: Bool = false
  @State private var selectedSeasonNumber: Int?

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
      }
      .padding(.bottom, 32)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(Color.KinoPub.background)
    // Let the hero cover bleed up under the (transparent) navigation bar.
    .ignoresSafeArea(edges: .top)
    #if os(iOS)
    .toolbar(.hidden, for: .tabBar)
    .toolbarBackground(.hidden, for: .navigationBar)
    .toolbarColorScheme(.dark, for: .navigationBar)
    #endif
    .task {
      itemModel.fetchData()
      itemModel.loadBookmarkFolders()
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
    HeroBackdrop(imageURL: mediaItem.posters.wide ?? mediaItem.posters.big, height: 460, tallBlur: true) {
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
    let duration = mediaItem.duration.totalFormatted
    if !duration.isEmpty {
      items.append(.init(text: duration, isBadge: false))
    }
    if let quality = qualityBadgeText {
      items.append(.init(text: quality, isBadge: true))
    }
    if let ac3 = mediaItem.ac3, ac3 > 0 {
      items.append(.init(text: "AC3", isBadge: true))
    }
    if let imdbRating = mediaItem.imdbRating, imdbRating > 0 {
      items.append(.init(text: "IMDb \(String(format: "%.1f", imdbRating))", isBadge: false))
    }
    if let kinopoiskRating = mediaItem.kinopoiskRating, kinopoiskRating > 0 {
      items.append(.init(text: "KP \(String(format: "%.1f", kinopoiskRating))", isBadge: false))
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
    HStack(spacing: 12) {
      playButton
      // Watchlist ("Буду смотреть") is a serials-only feature on kino.pub; for movies use Bookmarks.
      if mediaItem.isSeries {
        watchlistButton
      }
      watchedButton
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
  }

  private var watchlistButton: some View {
    let inWatchlist = mediaItem.inWatchlist == true
    return circleIconButton(inWatchlist ? "checkmark" : "plus",
                            accessibility: inWatchlist ? "Remove from Watchlist" : "Add to Watchlist") {
      itemModel.toggleWatchlist()
    }
  }

  private var watchedButton: some View {
    circleIconButton("eye", accessibility: "Mark Watched") {
      itemModel.toggleWatched()
    }
  }

  @ViewBuilder
  private var bookmarkMenu: some View {
    if !itemModel.bookmarkFolders.isEmpty {
      Menu {
        ForEach(itemModel.bookmarkFolders) { folder in
          Button(folder.title) {
            itemModel.toggleBookmark(folderId: folder.id)
          }
        }
      } label: {
        circleIcon("folder")
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
      circleIcon("arrow.down.to.line")
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
    if mediaItem.isSeries, let episode = seriesPlayEpisode {
      NavigationLink(value: itemModel.linkProvider.player(for: episode)) {
        playLabel(title)
      }
      #if os(macOS)
      .buttonStyle(.plain)
      #endif
    } else {
      NavigationLink(value: itemModel.linkProvider.player(for: mediaItem)) {
        playLabel(title)
      }
      #if os(macOS)
      .buttonStyle(.plain)
      #endif
    }
  }

  // MARK: - Continue ("Netflix-style") resume logic

  /// Ordered (season, episode) pairs used to compute what to continue.
  private var orderedEpisodes: [(season: Season, episode: Episode)] {
    (mediaItem.seasons ?? [])
      .sorted { $0.number < $1.number }
      .flatMap { season in season.episodes.sorted { $0.number < $1.number }.map { (season, $0) } }
  }

  /// The series episode to continue: the in-progress one, else the episode right after the
  /// last fully-watched one. Nil when there's nothing started / everything is finished.
  private var continueTarget: (season: Season, episode: Episode)? {
    let ordered = orderedEpisodes
    if let inProgress = ordered.last(where: { $0.episode.watching.time > 0 }) {
      return inProgress
    }
    if let lastWatched = ordered.lastIndex(where: { $0.episode.watched > 0 }) {
      let next = lastWatched + 1
      return next < ordered.count ? ordered[next] : nil
    }
    return nil
  }

  /// Whether the play button should read "Continue" rather than "Play"/"Watch".
  private var hasResume: Bool {
    if mediaItem.isSeries { return continueTarget != nil }
    return (mediaItem.videos?.first?.watching.time ?? 0) > 0
  }

  /// Episode to start for a series: the continue target if any, else the first episode.
  private var seriesPlayEpisode: Episode? {
    if let target = continueTarget {
      return filledEpisode(target.episode, in: target.season)
    }
    return firstPlayableEpisode
  }

  private func playLabel(_ title: String) -> some View {
    HStack(spacing: 8) {
      Image(systemName: "play.fill")
      Text(title).font(.system(size: 16, weight: .semibold))
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 22)
    .padding(.vertical, 12)
    .background(Capsule().fill(Color.KinoPub.accent))
  }

  private func circleIcon(_ systemName: String) -> some View {
    Image(systemName: systemName)
      .font(.system(size: 18, weight: .semibold))
      .foregroundStyle(.white)
      .frame(width: 50, height: 50)
      .background(Circle().fill(Color.white.opacity(0.18)))
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
                              progress: episodeProgress(episode))
                }
                #if os(macOS)
                .buttonStyle(.plain)
                #endif
                .id(episode.id)
                .contextMenu {
                  Button {
                    itemModel.toggleEpisodeWatched(episodeNumber: episode.number, season: season.number)
                  } label: {
                    Label(episode.watched > 0 ? "Mark as Unwatched".localized : "Mark as Watched".localized,
                          systemImage: episode.watched > 0 ? "checkmark.circle" : "circle")
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
    return episode
  }

  private func episodeProgress(_ episode: Episode) -> Double? {
    if episode.watched > 0 { return 1.0 }
    if episode.watching.time > 0 { return 0.5 }
    return nil
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
              ForEach(itemModel.directorNames, id: \.self) { name in
                facetLink(itemModel.directorRoute(name)) {
                  facetValueText(name, isLink: itemModel.directorRoute(name) != nil)
                }
              }
            }
          }
        }
      }

      if let imdbRating = mediaItem.imdbRating {
        ratingRow(label: "IMDb",
                  value: String(format: "%.1f", imdbRating),
                  url: imdbURL)
      }

      if let kinopoiskRating = mediaItem.kinopoiskRating {
        ratingRow(label: "Kinopoisk",
                  value: String(format: "%.1f", kinopoiskRating),
                  url: kinopoiskURL)
      }
    }
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
                                          linkProvider: MainRoutesLinkProvider(),
                                          errorHandler: ErrorHandler()))
    }
  }
  static var previews: some View {
    NavigationStack {
      Preview()
    }
  }
}
