//
//  MediaShelf.swift
//
//
//  Apple TV-style titled horizontal carousel ("shelf").
//

import SwiftUI

/// A titled horizontal carousel that mimics the Apple TV app "shelf" rows.
/// Compose the row contents (poster cards, episode cards, etc.) via the trailing closure.
public struct MediaShelf<Content: View>: View {

  private let title: String
  private let showsChevron: Bool
  private let spacing: CGFloat
  private let horizontalPadding: CGFloat
  private let onHeaderTap: (() -> Void)?
  /// When set, the header becomes a `NavigationLink` to this value (resolved by the enclosing
  /// stack's `navigationDestination`). Use this — instead of `onHeaderTap` — to push a full "see
  /// all" page, since it works regardless of which navigation stack the shelf lives in.
  private let headerValue: (any Hashable)?
  private let content: Content

  public init(title: String,
              showsChevron: Bool = true,
              spacing: CGFloat = 14,
              horizontalPadding: CGFloat = 20,
              headerValue: (any Hashable)? = nil,
              onHeaderTap: (() -> Void)? = nil,
              @ViewBuilder content: () -> Content) {
    self.title = title
    self.showsChevron = showsChevron
    self.spacing = spacing
    self.horizontalPadding = horizontalPadding
    self.headerValue = headerValue
    self.onHeaderTap = onHeaderTap
    self.content = content()
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      header
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: spacing) {
          content
        }
        .padding(.horizontal, horizontalPadding)
      }
    }
  }

  @ViewBuilder
  private var header: some View {
    if let headerValue {
      NavigationLink(value: headerValue) { headerLabel }
        .buttonStyle(.plain)
    } else {
      Button(action: { onHeaderTap?() }) { headerLabel }
        .buttonStyle(.plain)
        .disabled(onHeaderTap == nil)
    }
  }

  private var headerLabel: some View {
    HStack(spacing: 6) {
      Text(title)
        .font(.system(size: 22, weight: .bold))
        .foregroundStyle(Color.KinoPub.text)
      if showsChevron && (onHeaderTap != nil || headerValue != nil) {
        Image(systemName: "chevron.right")
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(Color.KinoPub.subtitle)
      }
      Spacer(minLength: 0)
    }
    .contentShape(Rectangle())
    .padding(.horizontal, horizontalPadding)
  }
}
