//
//  KinoPubButtonTextStyle.swift
//
//
//  Created by Kirill Kunst on 4.08.2023.
//

import Foundation
import SwiftUI

/// Applies the standard KinoPub button label layout: horizontal padding,
/// a full-width / fixed-height frame and the shared title font.
///
/// This modifier is the single source of truth for button label metrics so that
/// ``KinoPubButton`` and any custom `Button` styled with ``KinoPubButtonStyle``
/// stay visually consistent.
public struct KinoPubButtonTextStyle: ViewModifier {

  /// Layout metrics shared across KinoPub buttons.
  enum Metrics {
    static let horizontalPadding: CGFloat = 8
    static let maxHeight: CGFloat = 40
    static let font: Font = .system(size: 16, weight: .semibold)
  }

  public init() {}

  public func body(content: Content) -> some View {
    content
      .padding(.horizontal, Metrics.horizontalPadding)
      .frame(maxWidth: .infinity, maxHeight: Metrics.maxHeight)
      .font(Metrics.font)
  }
}
