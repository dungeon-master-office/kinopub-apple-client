//
//  ContentItemsListView.swift
//
//
//  Created by Kirill Kunst on 24.07.2023.
//

import Foundation
import SwiftUI
import KinoPubBackend

public struct ContentItemsListView: View {

  var width: CGFloat
  @Binding public var items: [MediaItem]
  public var onLoadMoreContent: (MediaItem) -> Void
  public var onRefresh: @Sendable () async -> Void
  public var navigationLinkProvider: (MediaItem) -> any Hashable
  /// Optional per-item overlay (e.g. watched/downloaded status badges) injected by the app, since
  /// this component can't reach the app's state. Defaults to nothing.
  public var statusOverlay: (MediaItem) -> AnyView
  /// Optional per-item long-press / right-click context menu (e.g. "Remove from folder"). When nil,
  /// no context menu is attached.
  public var contextMenu: ((MediaItem) -> AnyView)?
  /// Optional content placed at the top of the scroll view, above the grid (e.g. a collection's meta
  /// header) so it scrolls away with the content instead of being pinned.
  public var header: AnyView

#if os(iOS)
  @Environment(\.horizontalSizeClass) private var sizeClass
#endif
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var useReducedThumbnailSize: Bool {
#if os(iOS)
    if sizeClass == .compact {
      return true
    }
#endif
    if dynamicTypeSize >= .xxxLarge {
      return true
    }

#if os(iOS)
    if width <= 390 {
      return true
    }
#elseif os(macOS)
    if width <= 520 {
      return true
    }
#endif

    return false
  }

  var cellSize: Double {
    useReducedThumbnailSize ? 150 : 172
  }

  var gridLayout: [GridItem] {
    PosterGridLayout.columns(width: width)
  }

  public init(width: CGFloat,
              items: Binding<[MediaItem]>,
              onLoadMoreContent: @escaping (MediaItem) -> Void,
              onRefresh: @escaping @Sendable () async -> Void,
              navigationLinkProvider: @escaping (MediaItem) -> any Hashable,
              statusOverlay: @escaping (MediaItem) -> AnyView = { _ in AnyView(EmptyView()) },
              contextMenu: ((MediaItem) -> AnyView)? = nil,
              header: AnyView = AnyView(EmptyView())) {
    self._items = items
    self.width = width
    self.onRefresh = onRefresh
    self.onLoadMoreContent = onLoadMoreContent
    self.navigationLinkProvider = navigationLinkProvider
    self.statusOverlay = statusOverlay
    self.contextMenu = contextMenu
    self.header = header
  }

  public var body: some View {
    ScrollView {
      header
      LazyVGrid(columns: gridLayout, spacing: 24, content: {
        ForEach(items, id: \.id) { item in
          itemCell(item)
        }
      })
      .padding(.horizontal, 20)
      .padding(.top, 8)
    }
    .refreshable(action: onRefresh)
  }

  @ViewBuilder
  private func itemCell(_ item: MediaItem) -> some View {
    let cell = NavigationLink(value: navigationLinkProvider(item)) {
      ContentItemView(mediaItem: item)
        .overlay(alignment: .topTrailing) { statusOverlay(item) }
        .onAppear { onLoadMoreContent(item) }
    }
    .buttonStyle(.plain)

    if let contextMenu {
      cell.contextMenu { contextMenu(item) }
    } else {
      cell
    }
  }

}

struct ContentItemsListView_Previews: PreviewProvider {

  struct Preview: View {
    @State var items: [MediaItem] = MediaItem.skeletonMock()

    var body: some View {
      GeometryReader { geometryProxy in
        ContentItemsListView(width: geometryProxy.size.width, items: $items, onLoadMoreContent: { _ in

        }, onRefresh: {

        }, navigationLinkProvider: { _ in
          return ""
        })
      }
    }
  }

  static var previews: some View {
    NavigationStack {
      Preview()
    }
  }
}
