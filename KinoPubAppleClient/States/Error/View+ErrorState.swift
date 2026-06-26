//
//  View+ErrorState.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 6.08.2023.
//

import Foundation
import SwiftUI
import PopupView
import KinoPubUI

/// Extension for the View protocol to handle error states.
extension View {
  
  /// Displays a popup with an error message when the error state is true.
  /// - Parameter state: A binding to the error state.
  /// - Returns: A modified view with error handling.
  func handleError(state: Binding<ErrorHandler.State>) -> some View {
    // A bottom overlay (not a full-screen popup): only the toast itself captures taps, so the
    // rest of the screen stays interactive. Tap the toast — or wait 5s — to dismiss it.
    self.overlay(alignment: .bottom) {
      if state.showError.wrappedValue {
        ToastContentView(message: .error(state.error.wrappedValue ?? ""))
          .padding()
          .transition(.move(edge: .bottom).combined(with: .opacity))
          .onTapGesture { state.showError.wrappedValue = false }
          .task(id: state.error.wrappedValue) {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            state.showError.wrappedValue = false
          }
      }
    }
    .animation(.spring(), value: state.showError.wrappedValue)
  }
  
}
