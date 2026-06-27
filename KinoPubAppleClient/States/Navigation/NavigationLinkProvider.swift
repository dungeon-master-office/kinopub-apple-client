//
//  NavigationLinkProvider.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 31.07.2023.
//

import Foundation
import SwiftUI
import KinoPubBackend
import KinoPubUI

protocol NavigationLinkProvider {
  func link(for item: MediaItem) -> any Hashable
  func player(for item: any PlayableItem) -> any Hashable
  func trailerPlayer(for item: any PlayableItem) -> any Hashable
  func seasons(for seasons: [Season]) -> any Hashable
  func season(for season: Season) -> any Hashable
  /// A filtered catalog (genre/country/year/etc.) opened from a detail page.
  func filteredCatalog(filter: MediaItemsFilter, title: String) -> (any Hashable)?
  /// A person search (actor/director) opened from a detail page.
  func personSearch(query: String, field: String, title: String) -> (any Hashable)?
}

/// The one and only link provider: every section now navigates with the shared `Route` type.
struct RouteLinkProvider: NavigationLinkProvider {
  func link(for item: MediaItem) -> any Hashable { Route.details(item) }
  func player(for item: any PlayableItem) -> any Hashable { Route.player(item) }
  func trailerPlayer(for item: any PlayableItem) -> any Hashable { Route.trailerPlayer(item) }
  func seasons(for seasons: [Season]) -> any Hashable { Route.seasons(seasons) }
  func season(for season: Season) -> any Hashable { Route.season(season) }
  func filteredCatalog(filter: MediaItemsFilter, title: String) -> (any Hashable)? {
    Route.filteredCatalog(filter, title)
  }
  func personSearch(query: String, field: String, title: String) -> (any Hashable)? {
    Route.personSearch(query, field, title)
  }
}

// MARK: - Shared destination resolver

extension View {
  /// Registers the shared `Route` destinations on a `NavigationStack`. Every section uses this,
  /// so all detail stacks share one path element type (see `Route`).
  func routeDestinations() -> some View {
    navigationDestination(for: Route.self) { route in
      RouteDestinationView(route: route)
    }
  }
}

/// Builds the destination view for any `Route`. Each destination constructs its own models from
/// the app context, so this is section-agnostic and can be reused everywhere.
struct RouteDestinationView: View {
  let route: Route

  @Environment(\.appContext) private var appContext
  @EnvironmentObject private var authState: AuthState
  @EnvironmentObject private var errorHandler: ErrorHandler

  var body: some View {
    switch route {
    case .details(let item):
      mediaItem(id: item.id)
    case .detailsByID(let id):
      mediaItem(id: id)
    case .seasons(let seasons):
      SeasonsView(model: SeasonsModel(seasons: seasons, linkProvider: RouteLinkProvider()))
    case .season(let season):
      SeasonView(model: SeasonModel(season: season, linkProvider: RouteLinkProvider()))
    case .player(let item):
      player(item, mode: .media)
    case .trailerPlayer(let item):
      player(item, mode: .trailer)
    case .filteredCatalog(let filter, let title):
      FilteredCatalogView(catalog: MediaCatalog(itemsService: appContext.contentService,
                                                authState: authState,
                                                errorHandler: errorHandler,
                                                filter: filter),
                          title: title,
                          linkProvider: RouteLinkProvider())
    case .personSearch(let query, let field, let title):
      PersonSearchView(model: SearchModel(itemsService: appContext.contentService,
                                          authState: authState,
                                          errorHandler: errorHandler),
                       query: query,
                       field: field,
                       title: title,
                       linkProvider: RouteLinkProvider())
    case .genre(let id, let title):
      GenreResultsView(model: SearchModel(itemsService: appContext.contentService,
                                          authState: authState,
                                          errorHandler: errorHandler),
                       genreId: id,
                       title: title)
    case .bookmark(let bookmark):
      BookmarkView(model: BookmarkModel(bookmark: bookmark,
                                        itemsService: appContext.contentService,
                                        actionsService: appContext.actionsService,
                                        errorHandler: errorHandler))
    case .collection(let collection):
      CollectionDetailView(model: CollectionDetailModel(collection: collection,
                                                        collectionsService: appContext.collectionsService,
                                                        errorHandler: errorHandler))
    case .mediaList(let items, let title):
      MediaListGridView(items: items, title: title)
    case .castCrew(let people, let title):
      SearchCastCrewView(people: people, title: title)
    }
  }

  @ViewBuilder
  private func mediaItem(id: Int) -> some View {
    MediaItemView(model: MediaItemModel(mediaItemId: id,
                                        itemsService: appContext.contentService,
                                        downloadManager: appContext.downloadManager,
                                        linkProvider: RouteLinkProvider(),
                                        errorHandler: errorHandler))
  }

  @ViewBuilder
  private func player(_ item: any PlayableItem, mode: WatchMode) -> some View {
    PlayerView(manager: PlayerManager(playItem: item,
                                      watchMode: mode,
                                      downloadedFilesDatabase: appContext.downloadedFilesDatabase,
                                      actionsService: appContext.actionsService))
  }
}

/// Self-contained genre browse grid (owns its own `SearchModel`) so it can be created from the
/// shared route resolver without depending on any screen's view model.
struct GenreResultsView: View {
  @StateObject private var model: SearchModel
  private let genreId: Int
  private let title: String

  init(model: @autoclosure @escaping () -> SearchModel, genreId: Int, title: String) {
    _model = StateObject(wrappedValue: model())
    self.genreId = genreId
    self.title = title
  }

  var body: some View {
    WidthReader { width in
      ScrollView {
        LazyVGrid(columns: PosterGridLayout.columns(width: width), spacing: 16) {
          ForEach(model.genreResults, id: \.id) { item in
            if item.skeleton ?? false {
              PosterCard.placeholder(width: nil)
            } else {
              NavigationLink(value: Route.details(item)) {
                PosterCard(imageURL: item.posters.medium, title: item.localizedTitle, width: nil)
              }
#if os(macOS)
              .buttonStyle(.plain)
#endif
            }
          }
        }
        .padding(16)
      }
    }
    .background(Color.KinoPub.background)
    .navigationTitle(title)
    .task {
      await model.loadGenreResults(genreId: genreId)
    }
  }
}
