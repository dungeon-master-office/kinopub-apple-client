//
//  NavigationState.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 31.07.2023.
//

import Foundation
import SwiftUI

class NavigationState: ObservableObject {
  @Published var columnVisibility = NavigationSplitViewVisibility.all
  @Published var selectedTab: NavigationTabs = .main
  @Published var sidebarSelection: SidebarItem? = .new
  @Published var searchRoutes: [SearchRoutes] = []
  /// Home's own navigation path. Kept separate from `mainRoutes` (the category catalogs) so two
  /// NavigationStacks never bind the same path during a sidebar transition (that crashed).
  @Published var homeRoutes: [MainRoutes] = []
  @Published var mainRoutes: [MainRoutes] = []
  @Published var bookmarksRoutes: [BookmarksRoutes] = []
  @Published var historyRoutes: [HistoryRoutes] = []
  @Published var watchingRoutes: [WatchingRoutes] = []
  @Published var downloadsRoutes: [DownloadsRoutes] = []
  @Published var collectionsRoutes: [CollectionsRoutes] = []
  /// A filter to apply when deep-linking into a Library category section (e.g. tapping a
  /// genre on a title selects that category in the sidebar and pre-filters it). Consumed once.
  @Published var pendingCategoryFilter: MediaItemsFilter?
}
