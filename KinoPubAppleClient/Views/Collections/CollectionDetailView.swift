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

  private var itemsGrid: some View {
    GeometryReader { geometryProxy in
      ContentItemsListView(width: geometryProxy.size.width,
                           items: $model.items,
                           onLoadMoreContent: { _ in },
                           onRefresh: {
                             await model.refresh()
                           },
                           navigationLinkProvider: { item in
                             CollectionsRoutesLinkProvider().link(for: item)
                           })
    }
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
