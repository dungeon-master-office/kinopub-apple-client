//
//  SidebarNavigationDetail.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 11.08.2023.
//

import Foundation
import SwiftUI
import KinoPubBackend

struct SidebarNavigationDetail: View {
  @Environment(\.appContext) var appContext
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var errorHandler: ErrorHandler
  @EnvironmentObject var authState: AuthState

  @Binding var selection: SidebarItem?

  var body: some View {
    switch selection ?? .new {
    case .search:
      search
    case .new:
      home
    case .category(let type):
      mainCatalog(contentType: type, shortcut: .hot)
        .id("library-\(type.rawValue)")
    case .preset(let preset):
      FilteredCatalogView(catalog: MediaCatalog(itemsService: appContext.contentService,
                                                authState: authState,
                                                errorHandler: errorHandler,
                                                filter: preset.filter),
                          title: preset.title.localized,
                          linkProvider: RouteLinkProvider())
        .id("preset-\(preset.rawValue)")
    case .sport:
      sport
    case .collections:
      collections
    case .newEpisodes:
      // "New episodes" and "Watching" are both WatchingView — distinct ids so switching between them
      // doesn't reuse the wrong model (same view type would otherwise share one @StateObject).
      newEpisodes.id("section-new-episodes")
    case .watching:
      watching.id("section-watching")
    case .bookmarks:
      bookmarks
    case .history:
      history
    case .downloads:
      downloads
    case .profile:
      profile
    }
  }

  var search: some View {
    SearchView(model: SearchModel(itemsService: appContext.contentService,
                                  authState: authState,
                                  errorHandler: errorHandler))
  }

  var home: some View {
    HomeView(model: HomeModel(itemsService: appContext.contentService,
                              authState: authState,
                              errorHandler: errorHandler))
  }

  /// The pending deep-link filter if it targets this content type.
  private func categoryFilter(for type: MediaType) -> MediaItemsFilter? {
    navigationState.pendingCategoryFilter?.contentType == type ? navigationState.pendingCategoryFilter : nil
  }

  func mainCatalog(contentType: MediaType, shortcut: MediaShortcut) -> some View {
    MainView(catalog: MediaCatalog(itemsService: appContext.contentService,
                                   authState: authState,
                                   errorHandler: errorHandler,
                                   contentType: contentType,
                                   shortcut: shortcut,
                                   filter: categoryFilter(for: contentType)))
  }

  var sport: some View {
    SportView(model: SportModel(itemsService: appContext.contentService,
                                epgService: appContext.epgService,
                                authState: authState,
                                errorHandler: errorHandler))
  }

  var collections: some View {
    CollectionsView(model: CollectionsModel(collectionsService: appContext.collectionsService,
                                            authState: authState,
                                            errorHandler: errorHandler))
  }

  var newEpisodes: some View {
    WatchingView(model: WatchingModel(itemsService: appContext.contentService,
                                      authState: authState,
                                      errorHandler: errorHandler,
                                      tab: .newEpisodes))
  }

  var watching: some View {
    WatchingView(model: WatchingModel(itemsService: appContext.contentService,
                                      authState: authState,
                                      errorHandler: errorHandler,
                                      tab: .watchlist))
  }

  var bookmarks: some View {
    BookmarksView(catalog: BookmarksCatalog(itemsService: appContext.contentService,
                                            authState: authState,
                                            errorHandler: errorHandler))
  }

  var history: some View {
    HistoryView(catalog: HistoryModel(itemsService: appContext.contentService,
                                      authState: authState,
                                      errorHandler: errorHandler))
  }

  var downloads: some View {
    DownloadsView(catalog: DownloadsCatalog(downloadsDatabase: appContext.downloadedFilesDatabase, downloadManager: appContext.downloadManager))
  }

  var profile: some View {
    ProfileView(model: ProfileModel(userService: appContext.userService,
                                    errorHandler: errorHandler,
                                    authState: authState))
  }
}

struct SidebarNavigationDetail_Previews: PreviewProvider {
  struct Preview: View {
    @State private var selection: SidebarItem? = .new
    var body: some View {
      SidebarNavigationDetail(selection: $selection)
    }
  }
  static var previews: some View {
    Preview()
  }
}
