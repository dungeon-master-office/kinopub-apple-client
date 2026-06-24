//
//  KinoPubButtonColor.swift
//
//
//  Created by Kirill Kunst on 31.07.2023.
//

import Foundation
import SwiftUI

/// The semantic color palette used by KinoPub buttons.
///
/// Each case maps to a concrete SwiftUI `Color` from the `Color.KinoPub` palette
/// via the ``color`` property, keeping the visual styling in a single place.
public enum KinoPubButtonColor {
  case green
  case gray
  case red
  case blue

  /// The concrete SwiftUI color backing this semantic case.
  public var color: Color {
    switch self {
    case .green:
      return Color.KinoPub.accent
    case .red:
      return Color.KinoPub.accentRed
    case .gray:
      return Color.KinoPub.selectionBackground
    case .blue:
      return Color.KinoPub.accentBlue
    }
  }
}
