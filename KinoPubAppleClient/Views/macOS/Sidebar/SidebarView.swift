//
//  SidebarView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 11.08.2023.
//

import Foundation
import SwiftUI
import KinoPubUI
import KinoPubBackend

struct SidebarView: View {

  @Environment(\.appContext) var appContext
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var errorHandler: ErrorHandler
  @EnvironmentObject var authState: AuthState

  var body: some View {
    splitView
      .sheet(isPresented: $authState.shouldShowAuthentication, content: {
        authSheet
      })
      .environmentObject(navigationState)
      .environmentObject(errorHandler)
      .task {
        await authState.check()
      }
  }

  private var splitView: some View {
    NavigationSplitView(columnVisibility: $navigationState.columnVisibility) {
      Sidebar(selection: $navigationState.sidebarSelection)
    } detail: {
      SidebarNavigationDetail(selection: $navigationState.sidebarSelection)
    }
    // Each selection's detail hosts a NavigationStack with its own path *type* ([MainRoutes],
    // [DownloadsRoutes], [WatchingRoutes], …). NavigationSplitView keeps the detail column's
    // navigation state itself, so switching sections makes SwiftUI reconcile the previous
    // section's path against the new one and trap in NavigationColumnState with
    // AnyNavigationPath.Error.comparisonTypeMismatch. Re-identifying the whole split view per
    // selection tears down that column state so each section starts with a fresh, correctly-typed
    // stack. (A detail-only .id is not enough — the column state lives on the split view.)
    // The auth sheet + .task stay on the stable parent so they don't re-run on every switch.
    .id(navigationState.sidebarSelection)
    .accentColor(Color.KinoPub.accent)
  }

  var authSheet: some View {
    AuthView(model: AuthModel(authService: appContext.authService,
                              authState: authState,
                              errorHandler: errorHandler))
#if os(macOS)
    .frame(width: 600, height: 600)
#endif
  }

}

struct SideBarView_Previews: PreviewProvider {
  static var previews: some View {
    SidebarView()
  }
}
