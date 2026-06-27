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
  @Environment(\.sectionEmbedded) private var sectionEmbedded

  init(model: @autoclosure @escaping () -> CollectionsModel) {
    _model = StateObject(wrappedValue: model())
  }

  var body: some View {
    if sectionEmbedded {
      sectionContent
    } else {
      NavigationStack(path: $navigationState.collectionsRoutes) {
        sectionContent.routeDestinations()
      }
    }
  }

  private var sectionContent: some View {
    content
      .kinoScreen("Collections".localized)
      .toolbar {
        ToolbarItem(placement: .primaryAction) { sortMenu }
      }
      .refreshable { await model.refresh() }
      .handleError(state: $errorHandler.state)
  }

  @ViewBuilder
  private var content: some View {
    ScrollView {
      if model.isLoading {
        placeholderList
      } else if model.collections.isEmpty {
        emptyState.frame(minHeight: 320)
      } else {
        collectionsList
      }
    }
    .background(Color.KinoPub.background)
  }

  // MARK: - Sort

  // Icon-only toolbar menu, matching the sort control used elsewhere (bookmarks, collection detail).
  private var sortMenu: some View {
    Menu {
      Picker("Sort".localized, selection: $model.selectedSort) {
        ForEach(CollectionsSort.allCases) { sort in
          Text(sort.title).tag(sort)
        }
      }
    } label: {
      Image(systemName: "arrow.up.arrow.down")
    }
  }

  /// One horizontal shelf per collection (title → opens the collection), mirroring the Bookmarks list.
  private var collectionsList: some View {
    LazyVStack(alignment: .leading, spacing: 28) {
      ForEach(model.collections) { collection in
        MediaShelf(title: collection.title,
                   headerValue: Route.collection(collection)) {
          if let items = model.collectionItems[collection.id] {
            let shown = Array(items.prefix(10))
            ForEach(shown) { item in
              NavigationLink(value: Route.details(item)) {
                PosterCard(imageURL: item.posters.medium,
                           title: item.localizedTitle,
                           imdbRating: item.imdbRating,
                           kinopoiskRating: item.kinopoiskRating)
                .overlay(alignment: .topTrailing) { MediaCardStatusBadge(item: item) }
              }
              .buttonStyle(.plain)
            }
            // Trailing "+N more" card opens the full collection (same as tapping the header).
            let remaining = (collection.itemsCount ?? items.count) - shown.count
            if remaining > 0 {
              NavigationLink(value: Route.collection(collection)) {
                moreCard(remaining)
              }
              .buttonStyle(.plain)
            }
          } else {
            // Loading placeholder shelf.
            ForEach(0..<4, id: \.self) { _ in PosterCard.placeholder() }
          }
        }
        .onAppear { model.loadMoreContent(after: collection) }
      }
    }
    .padding(.vertical, 16)
  }

  /// "+N more" tile shown at the end of a collection shelf; matches the poster tile's footprint.
  private func moreCard(_ count: Int) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(Color.white.opacity(0.06))
        .frame(width: 140, height: 210)
        .overlay {
          VStack(spacing: 8) {
            Image(systemName: "arrow.right.circle.fill")
              .font(.system(size: 30))
              .foregroundStyle(Color.KinoPub.accent)
            Text("+\(count)")
              .font(.system(size: 20, weight: .bold))
              .foregroundStyle(Color.KinoPub.text)
            Text("More".localized)
              .font(.system(size: 13))
              .foregroundStyle(Color.KinoPub.subtitle)
          }
          .padding(8)
        }
        .overlay(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }
    .frame(width: 140)
  }

  /// Skeleton shelves shown while the collection list loads (matches the real shelf layout).
  private var placeholderList: some View {
    LazyVStack(alignment: .leading, spacing: 28) {
      ForEach(0..<4, id: \.self) { _ in
        MediaShelf(title: " ", showsChevron: false) {
          ForEach(0..<4, id: \.self) { _ in PosterCard.placeholder() }
        }
      }
    }
    .padding(.vertical, 16)
  }

  // MARK: - States

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
        // Stronger scrim so the title stays legible over busy poster art.
        LinearGradient(colors: [.clear, .black.opacity(0.5), .black.opacity(0.97)],
                       startPoint: .top, endPoint: .bottom)
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
                                            authState: AuthState(authService: AuthorizationServiceMock(), accessTokenService: AccessTokenServiceMock(), deviceService: DeviceServiceMock()),
                                            errorHandler: ErrorHandler()))
  }
}
