//
//  MainView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 22.07.2023.
//
import SwiftUI
import KinoPubUI
import KinoPubBackend

struct MainView: View {
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var errorHandler: ErrorHandler
  @EnvironmentObject var authState: AuthState
  @Environment(\.appContext) var appContext
  
  @StateObject private var catalog: MediaCatalog
  @State private var showShortCutPicker: Bool = false
  @State private var showFilterPicker: Bool = false
  
  init(catalog: @autoclosure @escaping () -> MediaCatalog) {
    _catalog = StateObject(wrappedValue: catalog())
  }
  
  var toolbarItemPlacement: ToolbarItemPlacement {
#if os(iOS)
    .topBarTrailing
#elseif os(macOS)
    .navigation
#endif
  }
  
  var body: some View {
    NavigationStack(path: $navigationState.mainRoutes) {
      VStack {
        if catalog.items.isEmpty && !catalog.query.isEmpty {
          emptyView
        } else {
          catalogView
        }
      }
      .searchable(text: $catalog.query, placement: .automatic)
      .navigationTitle(catalog.title.localized)
      .toolbar {
        ToolbarItem(placement: toolbarItemPlacement) {
          Button {
            showShortCutPicker = true
          } label: {
            Image(systemName: "arrow.up.arrow.down")
          }
        }
        
        ToolbarItem(placement: toolbarItemPlacement) {
          Button {
            showFilterPicker = true
          } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
          }
        }
      }
      .background(Color.KinoPub.background)
      .sheet(isPresented: $showShortCutPicker, content: {
        ShortcutSelectionView(shortcut: $catalog.shortcut,
                              mediaType: $catalog.contentType)
      })
      .sheet(isPresented: $showFilterPicker, content: {
        FilterView(model: FilterModel(), onApply: { filter in
          catalog.apply(filter: filter)
        }, onClear: {
          catalog.clearFilter()
        })
      })
      .navigationDestination(for: MainRoutes.self) { route in
        switch route {
        case .details(let item):
          MediaItemView(model: MediaItemModel(mediaItemId: item.id,
                                              itemsService: appContext.contentService,
                                              downloadManager: appContext.downloadManager,
                                              linkProvider: MainRoutesLinkProvider(),
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
          SeasonsView(model: SeasonsModel(seasons: seasons, linkProvider: MainRoutesLinkProvider()))
        case .season(let season):
          SeasonView(model: SeasonModel(season: season, linkProvider: MainRoutesLinkProvider()))
        case .filteredCatalog(let filter, let title):
          FilteredCatalogView(catalog: MediaCatalog(itemsService: appContext.contentService,
                                                    authState: authState,
                                                    errorHandler: errorHandler,
                                                    filter: filter),
                              title: title,
                              linkProvider: MainRoutesLinkProvider())
        case .personSearch(let query, let field, let title):
          PersonSearchView(model: SearchModel(itemsService: appContext.contentService,
                                              authState: authState,
                                              errorHandler: errorHandler),
                           query: query,
                           field: field,
                           title: title,
                           linkProvider: MainRoutesLinkProvider())
        }
      }
      .handleError(state: $errorHandler.state)
      .task {
        await catalog.fetchItems()
      }
    }
  }
  
  var catalogView: some View {
    GeometryReader { geometryProxy in
      ContentItemsListView(width: geometryProxy.size.width, items: $catalog.items, onLoadMoreContent: { item in
        catalog.loadMoreContent(after: item)
      }, onRefresh: {
        await catalog.refresh()
      }, navigationLinkProvider: { item in
        MainRoutesLinkProvider().link(for: item)
      })
    }
  }
  
  var emptyView: some View {
    Text("No resuts")
      .foregroundStyle(Color.KinoPub.text)
      .font(Font.KinoPub.subheader)
  }
}

struct MainView_Previews: PreviewProvider {
  @StateObject static var navState = NavigationState()

  static var previews: some View {
    MainView(catalog: MediaCatalog(itemsService: VideoContentServiceMock(), authState: AuthState(authService: AuthorizationServiceMock(), accessTokenService: AccessTokenServiceMock()), errorHandler: ErrorHandler()))
      .environmentObject(navState)
  }
}

// MARK: - Filtered catalog destination

/// A standalone, paginated catalog showing the results of a single preset
/// `MediaItemsFilter` (e.g. tapping a genre/country/year on a detail page).
/// It pushes detail links onto whichever NavigationStack already contains it,
/// via the supplied `linkProvider`.
struct FilteredCatalogView: View {
  @EnvironmentObject var errorHandler: ErrorHandler
  @StateObject private var catalog: MediaCatalog
  private let title: String
  private let linkProvider: NavigationLinkProvider

  init(catalog: @autoclosure @escaping () -> MediaCatalog,
       title: String,
       linkProvider: NavigationLinkProvider) {
    _catalog = StateObject(wrappedValue: catalog())
    self.title = title
    self.linkProvider = linkProvider
  }

  var body: some View {
    GeometryReader { geometryProxy in
      ContentItemsListView(width: geometryProxy.size.width, items: $catalog.items, onLoadMoreContent: { item in
        catalog.loadMoreContent(after: item)
      }, onRefresh: {
        await catalog.refresh()
      }, navigationLinkProvider: { item in
        linkProvider.link(for: item)
      })
    }
    .background(Color.KinoPub.background)
    .navigationTitle(title)
    .task {
      await catalog.fetchItems()
    }
    .handleError(state: $errorHandler.state)
  }
}

// MARK: - Person search destination

/// A standalone results screen for a preset person search (actor/director).
/// Runs the query against the given `field` ("cast"/"director") on appear and
/// pushes detail links via the supplied `linkProvider`.
struct PersonSearchView: View {
  @EnvironmentObject var errorHandler: ErrorHandler
  @StateObject private var model: SearchModel
  private let query: String
  private let field: String
  private let title: String
  private let linkProvider: NavigationLinkProvider

  private let resultsColumns = [GridItem(.adaptive(minimum: 130), spacing: 16)]

  init(model: @autoclosure @escaping () -> SearchModel,
       query: String,
       field: String,
       title: String,
       linkProvider: NavigationLinkProvider) {
    _model = StateObject(wrappedValue: model())
    self.query = query
    self.field = field
    self.title = title
    self.linkProvider = linkProvider
  }

  var body: some View {
    ScrollView {
      LazyVGrid(columns: resultsColumns, spacing: 16) {
        ForEach(model.results, id: \.id) { item in
          if item.skeleton ?? false {
            PosterCard(imageURL: nil, title: "Placeholder")
              .redacted(reason: .placeholder)
          } else {
            NavigationLink(value: linkProvider.link(for: item)) {
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
      model.preset(query: query, field: field)
    }
    .handleError(state: $errorHandler.state)
  }
}
