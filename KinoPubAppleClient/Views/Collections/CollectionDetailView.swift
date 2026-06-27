//
//  CollectionDetailView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 24.06.2026.
//

import SwiftUI
import KinoPubUI
import KinoPubBackend

struct CollectionDetailView: View {
  @EnvironmentObject var errorHandler: ErrorHandler
  @StateObject private var model: CollectionDetailModel

  init(model: @autoclosure @escaping () -> CollectionDetailModel) {
    _model = StateObject(wrappedValue: model())
  }

  var body: some View {
    content
      .navigationTitle(model.collection.title)
      .background(Color.KinoPub.background)
      .task { await model.fetchItems() }
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          sortMenu
        }
      }
  }

  @ViewBuilder
  private var content: some View {
    if model.isLoading {
      loading
    } else if model.items.isEmpty {
      emptyState
    } else {
      itemsGrid
    }
  }

  // MARK: - Meta header

  private var metaHeader: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 12) {
        metaItem(systemImage: "film", value: "\(model.itemsCountText)")
        if let watchers = model.collection.watchers {
          metaItem(systemImage: "person.2", value: Self.compact(watchers))
        }
        if let views = model.collection.views {
          metaItem(systemImage: "eye", value: Self.compact(views))
        }
        if let updated = model.collection.updated {
          metaItem(systemImage: "clock", value: Self.dateText(from: updated))
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 20)
    .padding(.top, 12)
    .padding(.bottom, 4)
  }

  private func metaItem(systemImage: String, value: String) -> some View {
    HStack(spacing: 4) {
      Image(systemName: systemImage)
        .font(.system(size: 12))
      Text(value)
        .font(.system(size: 13, weight: .medium))
    }
    .foregroundStyle(Color.KinoPub.subtitle)
  }

  private var sortMenu: some View {
    Menu {
      ForEach(MediaItemsSort.allCases) { sort in
        Button {
          model.selectedSort = sort
        } label: {
          if model.selectedSort == sort {
            Label(sort.localizedTitle, systemImage: "checkmark")
          } else {
            Text(sort.localizedTitle)
          }
        }
      }
    } label: {
      // Icon-only toolbar control (a dot marks a non-default sort), matching the catalog screens.
      ZStack(alignment: .topTrailing) {
        Image(systemName: "arrow.up.arrow.down")
          .font(.system(size: 16))
        if model.selectedSort != .default {
          Circle()
            .fill(Color.KinoPub.accent)
            .frame(width: 7, height: 7)
            .offset(x: 5, y: -4)
        }
      }
      .foregroundStyle(Color.KinoPub.accent)
    }
    .menuStyle(.borderlessButton)
  }

  private var itemsGrid: some View {
    GeometryReader { geometryProxy in
      ContentItemsListView(width: geometryProxy.size.width,
                           items: $model.items,
                           onLoadMoreContent: { _ in },
                           onRefresh: {
                             await model.refresh()
                           },
                           navigationLinkProvider: { item in
                             RouteLinkProvider().link(for: item)
                           },
                           statusOverlay: { AnyView(MediaCardStatusBadge(item: $0)) },
                           // Meta scrolls with the grid (was a pinned header that broke the large-title
                           // → nav-bar-title collapse).
                           header: AnyView(metaHeader))
    }
  }

  // MARK: - Formatting

  /// Compact count, e.g. 12_345 -> "12.3K".
  private static func compact(_ value: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 1
    if value >= 1_000_000 {
      return (formatter.string(from: NSNumber(value: Double(value) / 1_000_000)) ?? "\(value)") + "M"
    } else if value >= 1_000 {
      return (formatter.string(from: NSNumber(value: Double(value) / 1_000)) ?? "\(value)") + "K"
    }
    return "\(value)"
  }

  private static func dateText(from timestamp: Int) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: date)
  }

  // MARK: - States

  private var loading: some View {
    VStack {
      Spacer()
      ProgressView().tint(Color.KinoPub.accent)
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var emptyState: some View {
    VStack(spacing: 10) {
      Spacer()
      Image(systemName: "rectangle.stack")
        .font(.system(size: 44))
        .foregroundStyle(Color.KinoPub.subtitle)
      Text("This collection is empty")
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(Color.KinoPub.subtitle)
        .multilineTextAlignment(.center)
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

struct CollectionDetailView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      CollectionDetailView(model: CollectionDetailModel(collection: Collection.mock(title: "Best of 2026"),
                                                        collectionsService: CollectionsServiceMock(),
                                                        errorHandler: ErrorHandler()))
    }
  }
}
