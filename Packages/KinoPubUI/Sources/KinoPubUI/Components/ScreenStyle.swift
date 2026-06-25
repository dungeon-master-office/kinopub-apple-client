//
//  ScreenStyle.swift
//  KinoPubUI
//
//  One shared modifier for every top-level screen's navigation chrome, so titles, background and
//  toolbar look and take up space identically across iOS and macOS (instead of each screen rolling
//  its own navigationTitle / display-mode / toolbar combination).
//

import SwiftUI

public extension View {
  /// Standard top-level screen chrome: a large, left-aligned title, the app background, and a
  /// matching toolbar — identical on every screen and platform.
  func kinoScreen(_ title: String) -> some View {
    modifier(KinoScreenModifier(title: title))
  }
}

private struct KinoScreenModifier: ViewModifier {
  let title: String

  func body(content: Content) -> some View {
    content
      .navigationTitle(title)
      .background(Color.KinoPub.background)
#if os(iOS)
      .navigationBarTitleDisplayMode(.large)
      .toolbarBackground(Color.KinoPub.background, for: .navigationBar)
#endif
  }
}
