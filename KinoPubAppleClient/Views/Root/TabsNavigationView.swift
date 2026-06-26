//
//  TabsView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 11.08.2023.
//

import Foundation
import SwiftUI
import KinoPubUI
import KinoPubBackend

struct TabsNavigationView: View {
  
  @Environment(\.appContext) var appContext
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var errorHandler: ErrorHandler
  @EnvironmentObject var authState: AuthState
  
  var placement: ToolbarPlacement {
#if os(iOS)
    .tabBar
#elseif os(macOS)
    .windowToolbar
#endif
  }
  
  var body: some View {
    TabView {
      searchTab
      mainTab
      sportTab
      collectionsTab
      bookmarksTab
      watchingTab
      historyTab
      downloadsTab
      profileTab
    }
    .accentColor(Color.KinoPub.accent)
    .sheet(isPresented: $authState.shouldShowAuthentication, content: {
      AuthView(model: AuthModel(authService: appContext.authService,
                                authState: authState,
                                errorHandler: errorHandler))
    })
    .environmentObject(navigationState)
    .environmentObject(errorHandler)
    .task {
      Task {
        await authState.check()
      }
    }
  }
  
  var searchTab: some View {
    SearchView(model: SearchModel(itemsService: appContext.contentService,
                                  authState: authState,
                                  errorHandler: errorHandler))
    .tag(NavigationTabs.search)
    .tabItem {
      Label("Search", systemImage: "magnifyingglass")
    }
    .toolbarBackground(Color.KinoPub.background, for: placement)
  }

  var mainTab: some View {
    HomeView(model: HomeModel(itemsService: appContext.contentService,
                              authState: authState,
                              errorHandler: errorHandler))
    .tag(NavigationTabs.main)
    .tabItem {
      Label("Home", systemImage: "house")
    }
    .toolbarBackground(Color.KinoPub.background, for: placement)
  }
  
  var sportTab: some View {
    SportView(model: SportModel(itemsService: appContext.contentService,
                                authState: authState,
                                errorHandler: errorHandler))
    .tag(NavigationTabs.sport)
    .tabItem {
      Label("Sport", systemImage: "sportscourt")
    }
    .toolbarBackground(Color.KinoPub.background, for: placement)
  }

  var collectionsTab: some View {
    CollectionsView(model: CollectionsModel(collectionsService: appContext.collectionsService,
                                            authState: authState,
                                            errorHandler: errorHandler))
    .tag(NavigationTabs.collections)
    .tabItem {
      Label("Collections", systemImage: "rectangle.stack")
    }
    .toolbarBackground(Color.KinoPub.background, for: placement)
  }

  var bookmarksTab: some View {
    BookmarksView(catalog: BookmarksCatalog(itemsService: appContext.contentService,
                                            authState: authState,
                                            errorHandler: errorHandler))
    .tag(NavigationTabs.bookmarks)
    .tabItem {
      Label("Bookmarks", systemImage: "bookmark")
    }
    .toolbarBackground(Color.KinoPub.background, for: placement)
  }
  
  var watchingTab: some View {
    WatchingView(model: WatchingModel(itemsService: appContext.contentService,
                                      authState: authState,
                                      errorHandler: errorHandler))
    .tag(NavigationTabs.watching)
    .tabItem {
      Label("Watching", systemImage: "play.tv")
    }
    .toolbarBackground(Color.KinoPub.background, for: placement)
  }

  var historyTab: some View {
    HistoryView(catalog: HistoryModel(itemsService: appContext.contentService,
                                      authState: authState,
                                      errorHandler: errorHandler))
    .tag(NavigationTabs.history)
    .tabItem {
      Label("History", systemImage: "clock.arrow.circlepath")
    }
    .toolbarBackground(Color.KinoPub.background, for: placement)
  }

  var downloadsTab: some View {
    DownloadsView(catalog: DownloadsCatalog(downloadsDatabase: appContext.downloadedFilesDatabase, downloadManager: appContext.downloadManager))
      .tag(NavigationTabs.downloads)
      .tabItem {
        Label("Downloads", systemImage: "arrow.down.circle")
      }
      .toolbarBackground(Color.KinoPub.background, for: placement)
  }
  
  var profileTab: some View {
    ProfileView(model: ProfileModel(userService: appContext.userService,
                                    errorHandler: errorHandler,
                                    authState: authState))
      .tag(NavigationTabs.profile)
      .tabItem {
        Label("Profile", systemImage: "person.crop.circle")
      }
      .toolbarBackground(Color.KinoPub.background, for: placement)
  }
}

struct TabsNavigationView_Previews: PreviewProvider {
  static var previews: some View {
    TabsNavigationView()
  }
}
