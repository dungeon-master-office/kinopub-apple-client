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
    NavigationSplitView(columnVisibility: $navigationState.columnVisibility) {
      Sidebar(selection: $navigationState.sidebarSelection)
    } detail: {
      SidebarNavigationDetail(selection: $navigationState.sidebarSelection)
        // Each selection's detail is a NavigationStack with its own path *type* ([MainRoutes],
        // [DownloadsRoutes], …). Without a stable per-selection identity, switching makes SwiftUI
        // reconcile the column's old path against the new one and trap with
        // AnyNavigationPath.Error.comparisonTypeMismatch. The id forces a fresh stack per section.
        .id(navigationState.sidebarSelection)
    }
    .accentColor(Color.KinoPub.accent)
    .sheet(isPresented: $authState.shouldShowAuthentication, content: {
      authSheet
    })
    .environmentObject(navigationState)
    .environmentObject(errorHandler)
    .task {
      await authState.check()
    }
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
