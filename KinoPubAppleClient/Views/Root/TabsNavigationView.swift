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

// MARK: - "Back to Еще" affordance
//
// The custom "Ещё" tab swaps the chosen section in as the tab's own content, so the section keeps
// its single navigation bar (no double bar like the system "More" produced). MoreView publishes a
// back action through the environment; each top-level screen renders it as a leading bar button via
// `.moreBackButton()` — nil on the bottom-bar tabs, so they show no back button.

private struct MoreBackActionKey: EnvironmentKey {
  static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
  var moreBackAction: (() -> Void)? {
    get { self[MoreBackActionKey.self] }
    set { self[MoreBackActionKey.self] = newValue }
  }
}

extension View {
  /// Adds a leading "‹ Ещё" button when presented inside the custom More tab (no-op otherwise).
  func moreBackButton() -> some View { modifier(MoreBackButtonModifier()) }
}

private struct MoreBackButtonModifier: ViewModifier {
  @Environment(\.moreBackAction) private var moreBackAction

  func body(content: Content) -> some View {
#if os(iOS)
    content.toolbar {
      if let moreBackAction {
        ToolbarItem(placement: .topBarLeading) {
          Button(action: moreBackAction) {
            Label("More".localized, systemImage: "chevron.left")
          }
        }
      }
    }
#else
    content
#endif
  }
}

struct TabsNavigationView: View {

  @Environment(\.appContext) var appContext
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var errorHandler: ErrorHandler
  @EnvironmentObject var authState: AuthState
  @EnvironmentObject var networkMonitor: NetworkMonitor

  @State private var selectedTab: NavigationTabs = .main
  /// Section the user was on before going offline, restored automatically on reconnect.
  @State private var sectionBeforeOffline: NavigationTabs?
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
      // Поиск · Я смотрю · Главная (center) · История · Ещё
      searchTab
      watchingTab
      mainTab
      historyTab
      moreTab
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
      // Downloads live inside "Ещё"; jump there (MoreView opens Downloads automatically offline).
      if selectedTab != .more { sectionBeforeOffline = selectedTab }
      selectedTab = .more
    } else {
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
        selectedTab = .more
      }
      .background(Color.KinoPub.background)
    }
  }

  // MARK: - Bottom-bar tabs

  var searchTab: some View {
    networkGated {
      SearchView(model: SearchModel(itemsService: appContext.contentService,
                                    authState: authState,
                                    errorHandler: errorHandler))
    }
    .tag(NavigationTabs.search)
    .tabItem { Label("Search", systemImage: "magnifyingglass") }
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
    .tabItem { Label("Watching", systemImage: "play.tv") }
    .toolbarBackground(Color.KinoPub.background, for: placement)
  }

  var mainTab: some View {
    networkGated {
      HomeView(model: HomeModel(itemsService: appContext.contentService,
                                authState: authState,
                                errorHandler: errorHandler))
    }
    .tag(NavigationTabs.main)
    .tabItem { Label("Home", systemImage: "house") }
    .toolbarBackground(Color.KinoPub.background, for: placement)
  }

  var historyTab: some View {
    networkGated {
      HistoryView(catalog: HistoryModel(itemsService: appContext.contentService,
                                        authState: authState,
                                        errorHandler: errorHandler))
    }
    .tag(NavigationTabs.history)
    .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
    .toolbarBackground(Color.KinoPub.background, for: placement)
  }

  var moreTab: some View {
    MoreView()
      .tag(NavigationTabs.more)
      .tabItem { Label("More", systemImage: "ellipsis") }
      .toolbarBackground(Color.KinoPub.background, for: placement)
  }
}

// MARK: - Custom "Ещё" — mirrors the iPad sidebar, one navigation bar per screen

struct MoreView: View {
  @Environment(\.appContext) private var appContext
  @EnvironmentObject private var navigationState: NavigationState
  @EnvironmentObject private var errorHandler: ErrorHandler
  @EnvironmentObject private var authState: AuthState
  @EnvironmentObject private var networkMonitor: NetworkMonitor

  @State private var selected: SidebarItem?

  /// Rows mirror the iPad sidebar's Library + Other groups (Home/Search live in the bottom bar).
  private var libraryRows: [SidebarItem] {
    SidebarItem.libraryCategories.map { .category($0) } + [.sport, .collections]
  }
  private var otherRows: [SidebarItem] { [.newEpisodes, .watching, .bookmarks, .downloads] }

  var body: some View {
    Group {
      if let selected {
        sectionView(selected)
          .environment(\.moreBackAction, { withAnimation { self.selected = nil } })
      } else {
        NavigationStack {
          List {
            Section("Library".localized) { ForEach(libraryRows) { row($0) } }
            Section("Other".localized) { ForEach(otherRows) { row($0) } }
            Section { row(.profile) }
          }
#if os(iOS)
          .listStyle(.insetGrouped)
#endif
          .scrollContentBackground(.hidden)
          .kinoScreen("More".localized)
        }
      }
    }
    // Offline: open Downloads automatically (the only fully-available section).
    .onChange(of: networkMonitor.isOnline) { online in
      if !online { selected = .downloads }
      else if selected != nil && selected?.isAvailableOffline == false { selected = nil }
    }
    .onAppear {
      if !networkMonitor.isOnline { selected = .downloads }
    }
  }

  @ViewBuilder
  private func row(_ item: SidebarItem) -> some View {
    let locked = !networkMonitor.isOnline && !item.isAvailableOffline
    Button {
      guard !locked else { return }
      withAnimation { selected = item }
    } label: {
      HStack {
        Label(item.title.localized, systemImage: item.systemImage)
        Spacer()
        if locked {
          Image(systemName: "lock.fill").font(.caption2)
        } else {
          Image(systemName: "chevron.right").font(.caption2)
        }
      }
      .foregroundStyle(locked ? Color.KinoPub.subtitle : Color.KinoPub.text)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .listRowBackground(Color.KinoPub.background)
  }

  @ViewBuilder
  private func sectionView(_ item: SidebarItem) -> some View {
    switch item {
    case .category(let type):
      MainView(catalog: MediaCatalog(itemsService: appContext.contentService,
                                     authState: authState,
                                     errorHandler: errorHandler,
                                     contentType: type,
                                     shortcut: .hot,
                                     filter: nil))
    case .sport:
      SportView(model: SportModel(itemsService: appContext.contentService,
                                  authState: authState,
                                  errorHandler: errorHandler))
    case .collections:
      CollectionsView(model: CollectionsModel(collectionsService: appContext.collectionsService,
                                              authState: authState,
                                              errorHandler: errorHandler))
    case .newEpisodes:
      WatchingView(model: WatchingModel(itemsService: appContext.contentService,
                                        authState: authState,
                                        errorHandler: errorHandler,
                                        tab: .newEpisodes))
    case .watching:
      WatchingView(model: WatchingModel(itemsService: appContext.contentService,
                                        authState: authState,
                                        errorHandler: errorHandler,
                                        tab: .watchlist))
    case .bookmarks:
      BookmarksView(catalog: BookmarksCatalog(itemsService: appContext.contentService,
                                              authState: authState,
                                              errorHandler: errorHandler))
    case .downloads:
      DownloadsView(catalog: DownloadsCatalog(downloadsDatabase: appContext.downloadedFilesDatabase,
                                              downloadManager: appContext.downloadManager))
    case .profile:
      ProfileView(model: ProfileModel(userService: appContext.userService,
                                      errorHandler: errorHandler,
                                      authState: authState))
    default:
      EmptyView()
    }
  }
}

struct TabsNavigationView_Previews: PreviewProvider {
  static var previews: some View {
    TabsNavigationView()
  }
}
