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
  @StateObject private var itemModel: MediaItemModel

  @State private var plotExpanded: Bool = false

  // Download flow (mirrors the mechanism previously in MediaItemDescriptionCard).
  @State private var selectedDownloadableItem: DownloadableMediaItem?
  @State private var showDownloadPicker: Bool = false
  @State private var showDownloadableItemPicker: Bool = false

  init(model: @autoclosure @escaping () -> MediaItemModel) {
    _itemModel = StateObject(wrappedValue: model())
  }

  private var mediaItem: MediaItem { itemModel.mediaItem }
  private var isSkeleton: Bool { !itemModel.itemLoaded }

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
    // Picker to select episode or entire media to download.
    .confirmationDialog("", isPresented: $showDownloadableItemPicker, titleVisibility: .hidden) {
      ForEach(mediaItem.downloadableItems) { item in
        Button(item.name) {
          selectedDownloadableItem = item
          showDownloadPicker = true
        }
      }
    }
    // Picker to select the quality of the item to download.
    .confirmationDialog("", isPresented: $showDownloadPicker, titleVisibility: .hidden) {
      ForEach(selectedDownloadableItem?.files ?? []) { file in
        Button(file.quality) {
          guard let selectedDownloadableItem else { return }
          itemModel.startDownload(item: selectedDownloadableItem, file: file)
        }
      }
    }
    #if os(iOS)
    .toolbar(.hidden, for: .tabBar)
    #endif
    .task {
      itemModel.fetchData()
      itemModel.loadBookmarkFolders()
    }
    .handleError(state: $errorHandler.state)
  }

  // MARK: - Hero

  private var hero: some View {
    HeroBackdrop(imageURL: mediaItem.posters.wide ?? mediaItem.posters.big, height: 460) {
      VStack(alignment: .leading, spacing: 10) {
        Text(mediaItem.localizedTitle)
          .font(.system(size: 34, weight: .bold))
          .foregroundStyle(.white)
          .skeleton(enabled: isSkeleton, size: CGSize(width: 240, height: 36))

        Text(genreLine)
          .font(.system(size: 15, weight: .medium))
          .foregroundStyle(.white.opacity(0.85))
          .skeleton(enabled: isSkeleton, size: CGSize(width: 180, height: 16))

        if !mediaItem.plot.isEmpty {
          VStack(alignment: .leading, spacing: 4) {
            Text(mediaItem.plot)
              .font(.system(size: 14))
              .foregroundStyle(.white.opacity(0.85))
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
      addMenu
      if mediaItem.trailer?.url != nil {
        NavigationLink(value: itemModel.linkProvider.trailerPlayer(for: mediaItem)) {
          circleIcon("film")
        }
        #if os(macOS)
        .buttonStyle(.plain)
        #endif
      }
    }
  }

  @ViewBuilder
  private var playButton: some View {
    let title = mediaItem.isSeries ? "Watch" : "Play"
    if mediaItem.isSeries, let firstEpisode = firstPlayableEpisode {
      NavigationLink(value: itemModel.linkProvider.player(for: firstEpisode)) {
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

  private var addMenu: some View {
    Menu {
      Button {
        itemModel.toggleWatchlist()
      } label: {
        Label("Add to Watchlist", systemImage: "text.badge.plus")
      }
      Button {
        itemModel.toggleWatched()
      } label: {
        Label("Mark Watched", systemImage: "eye")
      }
      if !itemModel.bookmarkFolders.isEmpty {
        Menu("Add to Bookmark…") {
          ForEach(itemModel.bookmarkFolders) { folder in
            Button(folder.title) {
              itemModel.toggleBookmark(folderId: folder.id)
            }
          }
        }
      }
      Button {
        startDownloadFlow()
      } label: {
        Label("Download", systemImage: "arrow.down.circle")
      }
    } label: {
      circleIcon("plus")
    }
    #if os(macOS)
    .menuStyle(.borderlessButton)
    .fixedSize()
    #endif
  }

  private func circleIcon(_ systemName: String) -> some View {
    Image(systemName: systemName)
      .font(.system(size: 18, weight: .semibold))
      .foregroundStyle(.white)
      .frame(width: 44, height: 44)
      .background(Circle().fill(Color.white.opacity(0.18)))
  }

  private func startDownloadFlow() {
    if (mediaItem.seasons?.count ?? 0) > 0 {
      showDownloadableItemPicker = true
    } else {
      selectedDownloadableItem = DownloadableMediaItem(name: mediaItem.title,
                                                       files: mediaItem.files,
                                                       mediaItem: mediaItem,
                                                       watchingMetadata: WatchingMetadata(id: mediaItem.id, video: nil, season: nil))
      showDownloadPicker = true
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
    if mediaItem.isSeries, let seasons = mediaItem.seasons {
      ForEach(seasons) { season in
        MediaShelf(title: season.fixedTitle, showsChevron: false) {
          ForEach(season.episodes, id: \.id) { episode in
            NavigationLink(value: itemModel.linkProvider.player(for: filledEpisode(episode, in: season))) {
              EpisodeCard(imageURL: episode.thumbnail,
                          overline: "Episode \(episode.number)",
                          title: episode.fixedTitle,
                          footnote: "\(max(episode.duration / 60, 1)) мин",
                          progress: episodeProgress(episode))
            }
            #if os(macOS)
            .buttonStyle(.plain)
            #endif
          }
        }
      }
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
      MediaShelf(title: "Trailers", showsChevron: false) {
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
      MediaShelf(title: "Related", showsChevron: false) {
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
      MediaShelf(title: "Cast & Crew", showsChevron: false) {
        ForEach(directors, id: \.self) { name in
          CastAvatarView(name: name, role: "Director")
        }
        ForEach(actors, id: \.self) { name in
          CastAvatarView(name: name, role: "Actor")
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
        let genres = mediaItem.genres.compactMap { $0.title }.joined(separator: " · ").uppercased()
        if !genres.isEmpty {
          Text(genres)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.KinoPub.subtitle)
        }
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

  // MARK: - Information & Languages

  private var infoSection: some View {
    MediaItemInfoSection(mediaItem: mediaItem)
      .padding(.horizontal, 20)
  }
}

// MARK: - Information & Languages

/// Apple TV-style "Information" + "Languages" block. Prefers a two-column
/// layout and falls back to a stacked one when too narrow. Preserves the
/// IMDB / Kinopoisk deep links (issue #44).
private struct MediaItemInfoSection: View {

  let mediaItem: MediaItem

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
      sectionTitle("Information")

      if mediaItem.year > 0 {
        infoRow(label: "Premiere", value: "\(mediaItem.year)")
      }

      let countries = mediaItem.countries.map { $0.title }.joined(separator: ", ")
      if !countries.isEmpty {
        infoRow(label: "Country", value: countries)
      }

      if !mediaItem.director.isEmpty {
        infoRow(label: "Director", value: mediaItem.director)
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
        sectionTitle("Languages")
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
