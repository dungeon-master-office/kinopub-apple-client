//
//  KinoPubButtonStyle.swift
//
//
//  Created by Kirill Kunst on 31.07.2023.
//

import Foundation
import SwiftUI

/// The visual style for KinoPub buttons.
///
/// Renders a filled, rounded-corner background using the supplied
/// ``KinoPubButtonColor`` and reacts to interaction:
/// - **Pressed**: slightly dims and scales down using `configuration.isPressed`.
/// - **Disabled**: dims via `@Environment(\.isEnabled)`.
///
/// The normal, enabled appearance is intentionally unchanged from the original
/// style (white label on the color background with a 6pt corner radius).
public struct KinoPubButtonStyle: ButtonStyle {

  /// Appearance tuning constants for interactive states.
  private enum Appearance {
    static let cornerRadius: CGFloat = 6.0
    static let pressedOpacity: Double = 0.85
    static let pressedScale: CGFloat = 0.97
    static let disabledOpacity: Double = 0.5
    static let animationDuration: Double = 0.15
  }

  private var buttonColor: KinoPubButtonColor

  /// Tracks the enabled state so the style can present a disabled appearance.
  @Environment(\.isEnabled) private var isEnabled: Bool

  public init(buttonColor: KinoPubButtonColor) {
    self.buttonColor = buttonColor
  }

  public func makeBody(configuration: Self.Configuration) -> some View {
    configuration.label
      .foregroundColor(.white)
      .background(buttonColor.color)
      .cornerRadius(Appearance.cornerRadius)
      .contentShape(RoundedRectangle(cornerRadius: Appearance.cornerRadius))
      .opacity(opacity(isPressed: configuration.isPressed))
      .scaleEffect(configuration.isPressed ? Appearance.pressedScale : 1.0)
      .animation(.easeInOut(duration: Appearance.animationDuration), value: configuration.isPressed)
  }

  /// Resolves the label opacity for the current interaction / enabled state.
  private func opacity(isPressed: Bool) -> Double {
    if !isEnabled {
      return Appearance.disabledOpacity
    }
    return isPressed ? Appearance.pressedOpacity : 1.0
  }
}
