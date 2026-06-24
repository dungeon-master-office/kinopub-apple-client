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
  @Published var mainRoutes: [MainRoutes] = []
  @Published var bookmarksRoutes: [BookmarksRoutes] = []
  @Published var historyRoutes: [HistoryRoutes] = []
  @Published var watchingRoutes: [WatchingRoutes] = []
  @Published var downloadsRoutes: [DownloadsRoutes] = []
}
