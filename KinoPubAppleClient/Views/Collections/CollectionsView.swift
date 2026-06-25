//
//  CollectionsView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 24.06.2026.
//

import SwiftUI
import KinoPubUI
import KinoPubBackend

struct CollectionsView: View {
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var authState: AuthState
  @EnvironmentObject var errorHandler: ErrorHandler
  @Environment(\.appContext) var appContext
  @StateObject private var model: CollectionsModel

  private let gridColumns = [GridItem(.adaptive(minimum: 200), spacing: 16, alignment: .top)]

  init(model: @autoclosure @escaping () -> CollectionsModel) {
    _model = StateObject(wrappedValue: model())
  }

  var body: some View {
    NavigationStack(path: $navigationState.collectionsRoutes) {
      content
        .kinoScreen("Collections".localized)
        .moreBackButton()
        .task { await model.fetchCollections() }
        .refreshable { await model.refresh() }
        .routeDestinations()
        .handleError(state: $errorHandler.state)
    }
  }

  @ViewBuilder
  private var content: some View {
    VStack(spacing: 0) {
      sortTabs
      if model.isLoading {
        loading
      } else if model.collections.isEmpty {
        emptyState
      } else {
        grid
      }
    }
  }

  // MARK: - Sort tabs

  private var sortTabs: some View {
    FilterChipBar(items: CollectionsSort.allCases.map { FilterChipItem(id: $0.apiValue, title: $0.title) },
                  selection: Binding(
                    get: { model.selectedSort.apiValue },
                    set: { value in
                      if let sort = CollectionsSort.allCases.first(where: { $0.apiValue == value }) {
                        model.selectedSort = sort
                      }
                    }
                  ))
  }

  private var grid: some View {
    ScrollView {
      LazyVGrid(columns: gridColumns, spacing: 16) {
        ForEach(model.collections) { collection in
          NavigationLink(value: Route.collection(collection)) {
            CollectionCard(collection: collection)
              .onAppear {
                model.loadMoreContent(after: collection)
              }
          }
#if os(macOS)
          .buttonStyle(.plain)
#endif
        }
      }
      .padding(16)
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
    EmptyStateView(systemImage: "rectangle.stack", title: "No collections yet".localized)
  }
}

/// A poster tile for a single collection.
struct CollectionCard: View {
  let collection: Collection

  private var imageURL: String? {
    collection.posters?.big ?? collection.posters?.medium ?? collection.posters?.small
  }

  var body: some View {
    Color.KinoPub.skeleton
      .aspectRatio(3.0 / 4.0, contentMode: .fit)
      .frame(maxWidth: .infinity)
      .overlay {
        CachedAsyncImage(url: URL(string: imageURL ?? "")) { image in
          image
            .resizable()
            .renderingMode(.original)
            .aspectRatio(contentMode: .fill)
        } placeholder: {
          Color.KinoPub.skeleton
        }
      }
      .overlay(alignment: .bottom) {
        LinearGradient(colors: [.clear, .black.opacity(0.15), .black.opacity(0.85)],
                       startPoint: .center, endPoint: .bottom)
      }
      .overlay(alignment: .bottomLeading) {
        Text(collection.title)
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(.white)
          .lineLimit(2)
          .multilineTextAlignment(.leading)
          .shadow(radius: 4)
          .padding(10)
      }
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
      )
  }
}

struct CollectionsView_Previews: PreviewProvider {
  static var previews: some View {
    CollectionsView(model: CollectionsModel(collectionsService: CollectionsServiceMock(),
                                            authState: AuthState(authService: AuthorizationServiceMock(), accessTokenService: AccessTokenServiceMock()),
                                            errorHandler: ErrorHandler()))
  }
}
