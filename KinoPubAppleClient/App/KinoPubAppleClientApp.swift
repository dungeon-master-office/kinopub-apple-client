//
//  KinoPubAppleClientApp.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 17.07.2023.
//

import SwiftUI
import KinoPubKit

enum WindowSize {
  static let macos = CGSize(width: 1280, height: 720)
}

@main
struct KinoPubAppleClientApp: App {
  
  @StateObject var navigationState = NavigationState()
  @StateObject var errorHandler = ErrorHandler()
  @StateObject var authState = AuthState(authService: AppContext.shared.authService,
                                         accessTokenService: AppContext.shared.accessTokenService,
                                         deviceService: AppContext.shared.deviceService)
  @StateObject var networkMonitor = NetworkMonitor()

#if os(macOS)
  @StateObject var windowSettings = WindowSettings()
#endif
  
#if os(iOS)
  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
#endif
  
#if os(macOS)
  @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
#endif
  
  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(\.appContext, AppContext.shared)
        .environmentObject(navigationState)
        .environmentObject(authState)
        .environmentObject(errorHandler)
        .environmentObject(networkMonitor)
        .environmentObject(AppContext.shared.libraryState)
        // Register this device's name once authorized, so it isn't listed as "unknown".
        .task(id: authState.userState) {
          if authState.userState == .authorized {
            await AppContext.shared.deviceService.registerDeviceName()
            // Advertise HEVC/4K so kino.pub serves HEVC + HDR10 streams to the native player.
            await AppContext.shared.deviceService.syncCapabilities()
          }
        }
        // Ask once for permission to post download-complete notifications.
        .task {
          await AppContext.shared.downloadNotificationManager.requestPermission()
        }
#if os(macOS)
        .frame(minWidth: WindowSize.macos.width, minHeight: WindowSize.macos.height)
#endif
    }
#if os(macOS)
    .windowResizability(.contentSize)
#endif
    
#if os(macOS)
    Settings {
      SettingsView()
        .environmentObject(windowSettings)
    }
#endif
  }
}
