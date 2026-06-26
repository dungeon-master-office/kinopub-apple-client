//
//  AppDelegate.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 24.07.2023.
//

import Foundation
import SwiftUI
import FirebaseCore
import KinoPubUI

#if os(iOS)
class AppDelegate: NSObject, UIApplicationDelegate {
  
  // This flag is used to lock orientation on the player view
  static var orientationLock = UIInterfaceOrientationMask.all
  
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
    FirebaseApp.configure()
    UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    ImageCache.shared.purgeExpired()
    return true
  }
  
  func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
    return AppDelegate.orientationLock
  }

  // Called when the app is relaunched in the background to finish events for a background URLSession.
  // We store the completion handler and invoke it once the session reports it finished its events.
  func application(_ application: UIApplication,
                   handleEventsForBackgroundURLSession identifier: String,
                   completionHandler: @escaping () -> Void) {
    AppContext.shared.downloadManager.backgroundCompletionHandler = completionHandler
  }
}
#endif

#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
  
  var window: NSWindow?
  
  func applicationDidFinishLaunching(_ notification: Notification) {
    FirebaseApp.configure()
    ImageCache.shared.purgeExpired()
  }
}
#endif
