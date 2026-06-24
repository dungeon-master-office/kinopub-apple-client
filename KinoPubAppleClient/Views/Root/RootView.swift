//
//  RootView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 17.07.2023.
//

import SwiftUI
import KinoPubUI
import KinoPubBackend
#if os(iOS)
import UIKit
#endif

struct RootView: View {

  var placement: ToolbarPlacement {
#if os(iOS)
    .tabBar
#elseif os(macOS)
    .windowToolbar
#endif
  }

  var body: some View {
#if os(iOS)
    // iPad uses the classic two-column NavigationSplitView sidebar layout,
    // iPhone keeps the bottom tab bar.
    if UIDevice.current.userInterfaceIdiom == .pad {
      SidebarView()
    } else {
      TabsNavigationView()
    }
#elseif os(macOS)
    SidebarView()
#endif
  }
}

struct RootView_Previews: PreviewProvider {
  static var previews: some View {
    RootView()
  }
}
