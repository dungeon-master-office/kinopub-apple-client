//
//  SearchView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 24.06.2026.
//

import SwiftUI
import KinoPubUI
import KinoPubBackend

struct SearchView: View {
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var authState: AuthState
  @EnvironmentObject var errorHandler: ErrorHandler
  @Environment(\.appContext) var appContext
  @StateObject private var model: SearchModel

  /// Selected results type filter; `nil` means "All".
  @State private var selectedResultType: MediaType?

  private let browseColumns = [GridItem(.adaptive(minimum: 220), spacing: 16)]
  private let resultsColumns = [GridItem(.adaptive(minimum: 130), spacing: 16)]

  init(model: @autoclosure @escaping () -> SearchModel) {
    _model = StateObject(wrappedValue: model())
  }

  var body: some View {
    NavigationStack(path: $navigationState.searchRoutes) {
      ScrollView {
        if model.query.trimmingCharacters(in: .whitespaces).isEmpty {
          discoveryContent
        } else {
          resultsContent
        }
      }
      .searchable(text: $model.query, placement: .automatic, prompt: "Shows & Movies")
      .navigationTitle("Search")
      .background(Color.KinoPub.background)
      .task {
        await model.loadGenres()
      }
      // A new query starts from the "All" type filter.
      .onChange(of: model.query) { _ in
        selectedResultType = nil
      }
      .navigationDestination(for: SearchRoutes.self) { route in
        switch route {
        case .details(let item):
          MediaItemView(model: MediaItemModel(mediaItemId: item.id,
                                              itemsService: appContext.contentService,
                                              downloadManager: appContext.downloadManager,
                                              linkProvider: SearchRoutesLinkProvider(),
                                              errorHandler: errorHandler))
        case .player(let item):
          PlayerView(manager: PlayerManager(playItem: item,
                                            watchMode: .media,
                                            downloadedFilesDatabase: appContext.downloadedFilesDatabase,
                                            actionsService: appContext.actionsService))
        case .trailerPlayer(let item):
          PlayerView(manager: PlayerManager(playItem: item,
                                            watchMode: .trailer,
                                            downloadedFilesDatabase: appContext.downloadedFilesDatabase,
                                            actionsService: appContext.actionsService))
        case .seasons(let seasons):
          SeasonsView(model: SeasonsModel(seasons: seasons, linkProvider: SearchRoutesLinkProvider()))
        case .season(let season):
          SeasonView(model: SeasonModel(season: season, linkProvider: SearchRoutesLinkProvider()))
        case .genre(let id, let title):
          genreResults(id: id, title: title)
        case .filteredCatalog(let filter, let title):
          FilteredCatalogView(catalog: MediaCatalog(itemsService: appContext.contentService,
                                                    authState: authState,
                                                    errorHandler: errorHandler,
                                                    filter: filter),
                              title: title,
                              linkProvider: SearchRoutesLinkProvider())
        case .personSearch(let query, let field, let title):
          PersonSearchView(model: SearchModel(itemsService: appContext.contentService,
                                              authState: authState,
                                              errorHandler: errorHandler),
                           query: query,
                           field: field,
                           title: title,
                           linkProvider: SearchRoutesLinkProvider())
        }
      }
      .handleError(state: $errorHandler.state)
    }
  }

  // MARK: - Discovery (empty query)

  var discoveryContent: some View {
    VStack(alignment: .leading, spacing: 24) {
      if !model.recentItems.isEmpty {
        recentSection
      }
      browseSection
    }
    .padding(16)
  }

  var recentSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Recent")
          .font(Font.KinoPub.subheader)
          .foregroundStyle(Color.KinoPub.text)
        Spacer()
        Button("Clear") {
          model.clearRecents()
        }
        .foregroundStyle(Color.KinoPub.accent)
      }

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          ForEach(model.recentItems) { recent in
            NavigationLink(value: SearchRoutes.details(MediaItem.mock(id: recent.id))) {
              recentCard(recent)
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
  }

  private func recentCard(_ recent: RecentSearchItem) -> some View {
    HStack(spacing: 12) {
      CachedAsyncImage(url: URL(string: recent.poster)) { image in
        image.resizable().aspectRatio(contentMode: .fill)
      } placeholder: {
        Color.KinoPub.skeleton
      }
      .frame(width: 100, height: 62)
      .clipped()
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

      VStack(alignment: .leading, spacing: 2) {
        Text(recent.title)
          .font(.system(size: 15, weight: .medium))
          .foregroundStyle(Color.KinoPub.text)
          .lineLimit(2)
        Text(recent.subtitle)
          .font(.system(size: 13))
          .foregroundStyle(Color.KinoPub.subtitle)
          .lineLimit(1)
      }
      .frame(width: 150, alignment: .leading)
    }
    .padding(8)
    .background(Color.white.opacity(0.06))
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  var browseSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Browse")
        .font(Font.KinoPub.subheader)
        .foregroundStyle(Color.KinoPub.text)

      LazyVGrid(columns: browseColumns, spacing: 16) {
        if model.genres.isEmpty {
          ForEach(MediaType.allCases) { type in
            NavigationLink(value: SearchRoutes.genre(0, type.title)) {
              BrowseCategoryCard(title: type.title)
            }
#if os(macOS)
            .buttonStyle(.plain)
#endif
          }
        } else {
          ForEach(model.genres, id: \.id) { genre in
            NavigationLink(value: SearchRoutes.genre(genre.id, genre.title)) {
              BrowseCategoryCard(title: genre.title, imageURL: model.genrePosters[genre.id])
            }
#if os(macOS)
            .buttonStyle(.plain)
#endif
          }
        }
      }
    }
  }

  // MARK: - Results (non-empty query)

  var resultsContent: some View {
    VStack(alignment: .leading, spacing: 12) {
      typeFilterBar
      LazyVGrid(columns: resultsColumns, spacing: 16) {
        ForEach(filteredResults, id: \.id) { item in
          if item.skeleton ?? false {
            PosterCard(imageURL: nil, title: "Placeholder")
              .redacted(reason: .placeholder)
          } else {
            NavigationLink(value: SearchRoutes.details(item)) {
              PosterCard(imageURL: item.posters.medium, title: item.localizedTitle)
            }
#if os(macOS)
            .buttonStyle(.plain)
#endif
            .simultaneousGesture(TapGesture().onEnded {
              model.recordRecent(item)
            })
          }
        }
      }
    }
    .padding(16)
  }

  // MARK: - Results type filter

  /// The results filtered by the selected type (or all when none selected).
  private var filteredResults: [MediaItem] {
    guard let selectedResultType else { return model.results }
    return model.results.filter { MediaType(rawValue: $0.type) == selectedResultType }
  }

  /// Content types present in the currently loaded results, in canonical order.
  private var availableResultTypes: [MediaType] {
    let present = Set(model.results.compactMap { MediaType(rawValue: $0.type) })
    return MediaType.allCases.filter { present.contains($0) }
  }

  private func resultCount(for type: MediaType?) -> Int {
    guard let type else { return model.results.count }
    return model.results.filter { MediaType(rawValue: $0.type) == type }.count
  }

  @ViewBuilder
  private var typeFilterBar: some View {
    // Only worth showing once results span more than one type.
    let types = availableResultTypes
    if types.count > 1 {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          typePill(title: "All".localized, count: resultCount(for: nil), type: nil)
          ForEach(types) { type in
            typePill(title: type.title.localized, count: resultCount(for: type), type: type)
          }
        }
      }
    }
  }

  private func typePill(title: String, count: Int, type: MediaType?) -> some View {
    let isSelected = selectedResultType == type
    return Button {
      selectedResultType = type
    } label: {
      Text("\(title) (\(count))")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(isSelected ? Color.white : Color.KinoPub.text)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
          Capsule().fill(isSelected ? Color.KinoPub.accent : Color.white.opacity(0.1))
        )
    }
    .buttonStyle(.plain)
  }

  // MARK: - Genre results destination

  func genreResults(id: Int, title: String) -> some View {
    ScrollView {
      LazyVGrid(columns: resultsColumns, spacing: 16) {
        ForEach(model.genreResults, id: \.id) { item in
          if item.skeleton ?? false {
            PosterCard(imageURL: nil, title: "Placeholder")
              .redacted(reason: .placeholder)
          } else {
            NavigationLink(value: SearchRoutes.details(item)) {
              PosterCard(imageURL: item.posters.medium, title: item.localizedTitle)
            }
#if os(macOS)
            .buttonStyle(.plain)
#endif
          }
        }
      }
      .padding(16)
    }
    .background(Color.KinoPub.background)
    .navigationTitle(title)
    .task {
      await model.loadGenreResults(genreId: id)
    }
  }
}

struct SearchView_Previews: PreviewProvider {
  @StateObject static var navState = NavigationState()

  static var previews: some View {
    SearchView(model: SearchModel(itemsService: VideoContentServiceMock(),
                                  authState: AuthState(authService: AuthorizationServiceMock(), accessTokenService: AccessTokenServiceMock()),
                                  errorHandler: ErrorHandler()))
      .environmentObject(navState)
  }
}
