//
//  SettingsView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 28.10.2023.
//

import Foundation
import SwiftUI
import KinoPubUI

#if os(macOS)
struct SettingsView: View {
  @EnvironmentObject var windowSettings: WindowSettings
  @AppStorage("alwaysOnTop") var alwaysOnTop: Bool = false
  @State private var cacheSize: String = ImageCache.shared.formattedDiskUsage()

  var body: some View {
    Form {
      Toggle("AlwaysOnTop", isOn: $windowSettings.alwaysOnTop)
      LabeledContent("Image Cache", value: cacheSize)
      Button("Clear Image Cache") {
        ImageCache.shared.clear()
        cacheSize = ImageCache.shared.formattedDiskUsage()
      }
    }
    .padding()
    .frame(width: 320, height: 220)
  }
}
#endif
