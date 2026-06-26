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

  /// On iOS < 26 puts a frosted-blur background behind the navigation bar (so content reads under a
  /// blur, not a hard fill). iOS 26 already supplies the translucent "Liquid Glass" bar, so we leave
  /// it to the system there.
  @ViewBuilder
  func navBarBlurBackground() -> some View {
#if os(iOS)
    if #available(iOS 26.0, *) {
      self
    } else {
      self.toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }
#else
    self
#endif
  }

  /// Immersive hero chrome (Home): on iOS 26 the artwork bleeds under the transparent glass bar; on
  /// older iOS the bar gets a blur and the safe area is restored so the hero sits below it.
  @ViewBuilder
  func heroNavBar() -> some View {
#if os(iOS)
    if #available(iOS 26.0, *) {
      self
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    } else {
      self
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
#else
    self
#endif
  }

  /// Shapes the context-menu "lift" preview to a rounded rectangle so a surrounding ScrollView /
  /// LazyVGrid / horizontal stack doesn't clip the lifted cell on long-press (rawtherapy technique:
  /// `.contentShape(.contextMenuPreview, …)` renders the preview in its own un-clipped layer). Apply
  /// to the same view that carries `.contextMenu`.
  @ViewBuilder
  func contextMenuPreviewShape(cornerRadius: CGFloat = 12) -> some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
#if os(iOS)
    if #available(iOS 17.0, *) {
      self.contentShape(.contextMenuPreview, shape)
    } else {
      self.contentShape(shape)
    }
#else
    self.contentShape(shape)
#endif
  }

  /// Wraps content in a floating capsule "island": real Liquid Glass on OS 26, an ultra-thin material
  /// capsule on older systems. Use for pinned/sticky section headers so they read as Apple-style
  /// floating islands over the scrolling content instead of a flat opaque bar.
  @ViewBuilder
  func glassCapsule() -> some View {
    if #available(iOS 26.0, macOS 26.0, *) {
      self.glassEffect(.regular, in: Capsule())
    } else {
      self.background(.ultraThinMaterial, in: Capsule())
    }
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
      .navBarBlurBackground()
#endif
  }
}
