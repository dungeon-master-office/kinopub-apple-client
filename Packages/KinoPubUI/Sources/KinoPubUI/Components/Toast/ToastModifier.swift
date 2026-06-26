//
//  ToastModifier.swift
//
//
//  A transient bottom toast that auto-dismisses, used for lightweight confirmations
//  (e.g. "added to bookmarks") and errors/warnings — styled by the message's `ToastStyle`.
//

import SwiftUI

public extension View {
  /// Presents a transient typed toast anchored to the bottom. Bind to an optional `ToastMessage`;
  /// set it (via `.success(…)`, `.error(…)`, `.info(…)`, `.warning(…)`) to show, and it clears
  /// itself after `duration`.
  func toast(message: Binding<ToastMessage?>, duration: TimeInterval = 2.0) -> some View {
    modifier(ToastModifier(message: message, duration: duration))
  }
}

private struct ToastModifier: ViewModifier {
  @Binding var message: ToastMessage?
  let duration: TimeInterval

  func body(content: Content) -> some View {
    content
      .overlay(alignment: .bottom) {
        if let message {
          ToastContentView(message: message)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: message) {
              try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
              withAnimation { self.message = nil }
            }
        }
      }
      .animation(.easeInOut(duration: 0.25), value: message)
  }
}
