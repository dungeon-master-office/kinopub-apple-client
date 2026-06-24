//
//  KinoPubButton.swift
//
//
//  Created by Kirill Kunst on 31.07.2023.
//

import Foundation
import SwiftUI

/// A primary, full-width KinoPub button with a title and a semantic color.
///
/// The label layout is provided by ``KinoPubButtonTextStyle`` and the visual
/// appearance (background, corner radius, pressed/disabled states) by
/// ``KinoPubButtonStyle`` so styling lives in a single place.
public struct KinoPubButton: View {

  /// Backward-compatible alias for the button color palette.
  ///
  /// The color type was extracted into the top-level ``KinoPubButtonColor`` so it
  /// can be reused independently, while existing call sites referring to
  /// `KinoPubButton.ButtonColor` (and `.green` / `.gray` / `.red` / `.blue`) keep
  /// compiling unchanged.
  public typealias ButtonColor = KinoPubButtonColor

  public var title: String
  public var color: ButtonColor
  public var action: () -> Void

  public init(title: String, color: ButtonColor, action: @escaping () -> Void) {
    self.title = title
    self.action = action
    self.color = color
  }

  public var body: some View {
    Button(action: action) {
      Text(title)
        .modifier(KinoPubButtonTextStyle())
    }
    .buttonStyle(KinoPubButtonStyle(buttonColor: color))
  }
}

struct KinoPubButton_Previews: PreviewProvider {
  static var previews: some View {
    KinoPubButton(title: "Watch", color: .green, action: {

    })
  }
}
