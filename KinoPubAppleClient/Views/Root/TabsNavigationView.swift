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
import KinoPubKit

struct TabsNavigationView: View {

  @Environment(\.appContext) var appContext
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var errorHandler: ErrorHandler
  @EnvironmentObject var authState: AuthState
  @EnvironmentObject var networkMonitor: NetworkMonitor

  @State private var selectedTab: NavigationTabs = .main
  /// Section the user was on before going offline, restored automatically on reconnect.
  @State private var sectionBeforeOffline: NavigationTabs?
  /// Briefly shows the green "back online" banner after reconnecting.
  @State private var showReconnected = false

  var placement: ToolbarPlacement {
#if os(iOS)
    .tabBar
#elseif os(macOS)
    .windowToolbar
#endif
  }
  
  var body: some View {
    TabView(selection: $selectedTab) {
      // Bottom bar (the first four) + system "More" (Еще) for the rest:
      // Поиск · Я смотрю · Главная (center) · История · Ещё
      searchTab
      watchingTab
      mainTab
      historyTab
      // —— overflow into "Ещё", mirroring the iPad sidebar (incl. the library categories) ——
      ForEach(SidebarItem.libraryCategories, id: \.self) { type in
        categoryTab(type)
      }
      sportTab
      collectionsTab
      newEpisodesTab
      bookmarksTab
      downloadsTab
      profileTab
    }
    .accentColor(Color.KinoPub.accent)
    .safeAreaInset(edge: .top, spacing: 0) {
      if let banner = bannerState {
        OfflineBanner(tone: banner.tone, title: banner.title)
          .transition(.move(edge: .top).combined(with: .opacity))
      }
    }
    .animation(.easeInOut(duration: 0.25), value: networkMonitor.isOnline)
    .animation(.easeInOut(duration: 0.25), value: showReconnected)
    .onChange(of: networkMonitor.isOnline) { online in
      handleConnectivityChange(online: online)
    }
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

  // MARK: - Offline mode

  private var bannerState: (tone: OfflineBanner.Tone, title: String)? {
    if !networkMonitor.isOnline {
      return (.warning, "You're offline — your downloads are available".localized)
    }
    if showReconnected {
      return (.success, "Back online".localized)
    }
    return nil
  }

  private func handleConnectivityChange(online: Bool) {
    if !online {
      // Entering offline: remember where we were and jump to the always-available Downloads.
      if selectedTab != .downloads && selectedTab != .profile {
        sectionBeforeOffline = selectedTab
      }
      selectedTab = .downloads
    } else {
      // Reconnected: auto-restore the previous section — unless the user is mid-playback / deep in
      // a downloaded item (don't interrupt). Show a brief "back online" confirmation either way.
      showReconnected = true
      if navigationState.downloadsRoutes.isEmpty, let previous = sectionBeforeOffline {
        selectedTab = previous
      }
      sectionBeforeOffline = nil
      Task {
        try? await Task.sleep(nanoseconds: 2_500_000_000)
        showReconnected = false
      }
    }
  }

  /// Network-only sections show a "needs connection" placeholder while offline.
  @ViewBuilder
  private func networkGated<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    if networkMonitor.isOnline {
      content()
    } else {
      OfflineUnavailableView(title: "Needs a connection".localized,
                             message: "This section isn't available offline.".localized,
                             actionTitle: "Go to Downloads".localized) {
        selectedTab = .downloads
      }
      .background(Color.KinoPub.background)
    }
  }
  
  var searchTab: some View {
    networkGated {
      SearchView(model: SearchModel(itemsService: appContext.contentService,
                                    authState: authState,
                                    errorHandler: errorHandler))
    }
    .tag(NavigationTabs.search)
    .tabItem {
      Label("Search", systemImage: "magnifyingglass")
    }
    .toolbarBackground(Color.KinoPub.background, for: placement)
  }

  var mainTab: some View {
    networkGated {
      HomeView(model: HomeModel(itemsService: appContext.contentService,
                                authState: authState,
                                errorHandler: errorHandler))
    }
    .tag(NavigationTabs.main)
    .tabItem {
      Label("Home", systemImage: "house")
    }
    .toolbarBackground(Color.KinoPub.background, for: placement)
  }

  /// A library category (Movies, Serials, …) — only surfaced on iPhone via the "More" (Ещё) overflow,
  /// mirroring the iPad sidebar's Library section.
  private func categoryTab(_ type: MediaType) -> some View {
    networkGated {
      MainView(catalog: MediaCatalog(itemsService: appContext.contentService,
                                     authState: authState,
                                     errorHandler: errorHandler,
                                     contentType: type,
                                     shortcut: .hot,
                                     filter: nil))
    }
    .tag(NavigationTabs.category(type))
    .tabItem {
      Label(type.title, systemImage: type.systemImage)
    }
    .toolbarBackground(Color.KinoPub.background, for: placement)
  }
  
  var sportTab: some View {
    networkGated {
      SportView(model: SportModel(itemsService: appContext.contentService,
                                  authState: authState,
                                  errorHandler: errorHandler))
    }
    .tag(NavigationTabs.sport)
    .tabItem {
      Label("Sport", systemImage: "sportscourt")
    }
    .toolbarBackground(Color.KinoPub.background, for: placement)
  }

  var collectionsTab: some View {
    networkGated {
      CollectionsView(model: CollectionsModel(collectionsService: appContext.collectionsService,
                                              authState: authState,
                                              errorHandler: errorHandler))
    }
    .tag(NavigationTabs.collections)
    .tabItem {
      Label("Collections", systemImage: "rectangle.stack")
    }
    .toolbarBackground(Color.KinoPub.background, for: placement)
  }

  var bookmarksTab: some View {
    networkGated {
      BookmarksView(catalog: BookmarksCatalog(itemsService: appContext.contentService,
                                              authState: authState,
                                              errorHandler: errorHandler))
    }
    .tag(NavigationTabs.bookmarks)
    .tabItem {
      Label("Bookmarks", systemImage: "bookmark")
    }
    .toolbarBackground(Color.KinoPub.background, for: placement)
  }
  
  var newEpisodesTab: some View {
    networkGated {
      WatchingView(model: WatchingModel(itemsService: appContext.contentService,
                                        authState: authState,
                                        errorHandler: errorHandler,
                                        tab: .newEpisodes))
    }
    .tag(NavigationTabs.newEpisodes)
    .tabItem {
      Label("New episodes", systemImage: "sparkles.tv")
    }
    .toolbarBackground(Color.KinoPub.background, for: placement)
  }

  var watchingTab: some View {
    networkGated {
      WatchingView(model: WatchingModel(itemsService: appContext.contentService,
                                        authState: authState,
                                        errorHandler: errorHandler,
                                        tab: .watchlist))
    }
    .tag(NavigationTabs.watching)
    .tabItem {
      Label("Watching", systemImage: "play.tv")
    }
    .toolbarBackground(Color.KinoPub.background, for: placement)
  }

  var historyTab: some View {
    networkGated {
      HistoryView(catalog: HistoryModel(itemsService: appContext.contentService,
                                        authState: authState,
                                        errorHandler: errorHandler))
    }
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
