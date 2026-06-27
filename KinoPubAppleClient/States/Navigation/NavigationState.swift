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
  // Every section navigates with the shared `Route` type (see Routes.swift). Separate arrays just
  // hold each section's own back-stack; sharing one element type means the NavigationSplitView
  // detail column never traps with AnyNavigationPath.comparisonTypeMismatch when switching
  // sections. (Main and Watching keep their stacks in local @State; Sport too.)
  @Published var searchRoutes: [Route] = []
  @Published var homeRoutes: [Route] = []
  @Published var bookmarksRoutes: [Route] = []
  @Published var historyRoutes: [Route] = []
  @Published var downloadsRoutes: [Route] = []
  @Published var collectionsRoutes: [Route] = []
  /// A filter to apply when deep-linking into a Library category section (e.g. tapping a
  /// genre on a title selects that category in the sidebar and pre-filters it). Consumed once.
  @Published var pendingCategoryFilter: MediaItemsFilter?

  /// Pop a section's navigation stack back to its root. Used when a sidebar row is tapped (including
  /// re-tapping the already-selected one) so it returns to the first screen, like a tab bar.
  /// Sections whose stack lives in local `@State` (Main / Watching / Sport / category / preset) are
  /// reset instead by `SidebarNavigationDetail`'s `.id(selection)` when the selection changes.
  func popToRoot(for item: SidebarItem) {
    switch item {
    case .search: searchRoutes = []
    case .new: homeRoutes = []
    case .bookmarks: bookmarksRoutes = []
    case .history: historyRoutes = []
    case .downloads: downloadsRoutes = []
    case .collections: collectionsRoutes = []
    default: break
    }
  }
}
