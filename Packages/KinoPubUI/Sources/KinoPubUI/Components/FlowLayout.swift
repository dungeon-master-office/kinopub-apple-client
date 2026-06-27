//
//  FlowLayout.swift
//
//
//  A simple wrapping (flow) layout: lays subviews left-to-right and wraps to the next line when the
//  next subview wouldn't fit the available width. Use it instead of a horizontal ScrollView/HStack
//  for metadata chips (directors, countries, ratings…) so content reflows on narrow screens.
//

import SwiftUI

public struct FlowLayout: Layout {
  public var spacing: CGFloat
  public var lineSpacing: CGFloat

  public init(spacing: CGFloat = 8, lineSpacing: CGFloat = 8) {
    self.spacing = spacing
    self.lineSpacing = lineSpacing
  }

  public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
    let maxWidth = proposal.width ?? .infinity
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rowHeight: CGFloat = 0
    var widest: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x > 0, x + size.width > maxWidth {
        // Wrap to a new line.
        widest = max(widest, x - spacing)
        x = 0
        y += rowHeight + lineSpacing
        rowHeight = 0
      }
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
    widest = max(widest, x - spacing)
    let width = proposal.width ?? max(widest, 0)
    return CGSize(width: width, height: y + rowHeight)
  }

  public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
    let maxWidth = bounds.width
    var x: CGFloat = bounds.minX
    var y: CGFloat = bounds.minY
    var rowHeight: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x > bounds.minX, (x - bounds.minX) + size.width > maxWidth {
        x = bounds.minX
        y += rowHeight + lineSpacing
        rowHeight = 0
      }
      subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
  }
}
