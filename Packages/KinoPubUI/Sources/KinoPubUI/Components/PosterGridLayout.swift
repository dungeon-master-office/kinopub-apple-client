//
//  PosterGridLayout.swift
//  KinoPubUI
//
//  One responsive layout for every poster grid. Instead of `GridItem(.adaptive(minimum:))` — which
//  silently drops to a single column on narrow widths (e.g. a 393pt iPhone with a 172pt minimum) —
//  we derive a DETERMINISTIC column count from the available width and a target tile size, then use
//  flexible columns so tiles always fill the row edge-to-edge. Mirrors the width-based approach used
//  in the rawtherapy queue grid.
//

import SwiftUI

public enum PosterGridLayout {

  /// Column count for the given container width: as many `targetTileWidth`-ish tiles as fit, clamped
  /// to `minColumns…maxColumns` (so a phone never falls to 1 column, and an iPad doesn't over-pack).
  public static func columnCount(width: CGFloat,
                                 targetTileWidth: CGFloat = 165,
                                 spacing: CGFloat = 16,
                                 horizontalPadding: CGFloat = 16,
                                 minColumns: Int = 2,
                                 maxColumns: Int = 8) -> Int {
    let usable = width - horizontalPadding * 2
    guard usable > 0 else { return minColumns }
    let fitted = Int(floor((usable + spacing) / (targetTileWidth + spacing)))
    return Swift.min(maxColumns, Swift.max(minColumns, fitted))
  }

  /// Flexible columns for a poster grid that fills the width evenly at the computed column count.
  public static func columns(width: CGFloat,
                             targetTileWidth: CGFloat = 165,
                             spacing: CGFloat = 16,
                             horizontalPadding: CGFloat = 16,
                             minColumns: Int = 2,
                             maxColumns: Int = 8) -> [GridItem] {
    let count = columnCount(width: width,
                            targetTileWidth: targetTileWidth,
                            spacing: spacing,
                            horizontalPadding: horizontalPadding,
                            minColumns: minColumns,
                            maxColumns: maxColumns)
    return Array(repeating: GridItem(.flexible(), spacing: spacing, alignment: .top), count: count)
  }
}

/// Reads the available width and hands it to its content — the safe way to size a grid responsively
/// inside a scroll view (a bare GeometryReader inside a ScrollView would collapse the layout). Place
/// this as the scroll view's container: `WidthReader { width in ScrollView { grid(width) } }`.
public struct WidthReader<Content: View>: View {
  private let content: (CGFloat) -> Content

  public init(@ViewBuilder content: @escaping (CGFloat) -> Content) {
    self.content = content
  }

  public var body: some View {
    GeometryReader { proxy in
      content(proxy.size.width)
    }
  }
}
