//
//  HistoryView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 24.06.2026.
//

import SwiftUI
import KinoPubUI
import KinoPubBackend
import SkeletonUI

struct HistoryView: View {
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var authState: AuthState
  @EnvironmentObject var errorHandler: ErrorHandler
  @Environment(\.appContext) var appContext
  @StateObject private var catalog: HistoryModel

  init(catalog: @autoclosure @escaping () -> HistoryModel) {
    _catalog = StateObject(wrappedValue: catalog())
  }

  var body: some View {
    NavigationStack(path: $navigationState.historyRoutes) {
      historyList
      .kinoScreen("History".localized)
      .routeDestinations()
      .handleError(state: $errorHandler.state)
      .toast(message: $catalog.toastMessage)
    }
  }

  // MARK: - Filter tabs

  var filterTabs: some View {
    FilterChipBar(items: filterItems,
                  selection: Binding(
                    get: { catalog.selectedType?.rawValue ?? "all" },
                    set: { catalog.selectedType = $0 == "all" ? nil : MediaType(rawValue: $0) }
                  ))
  }

  private var filterItems: [FilterChipItem] {
    [FilterChipItem(id: "all", title: "All".localized)]
      + catalog.availableTypes.map { FilterChipItem(id: $0.rawValue, title: $0.title.localized) }
  }

  // MARK: - History list

  var historyList: some View {
    GeometryReader { geometryProxy in
      if catalog.isLoadingSkeleton {
        skeletonList(width: geometryProxy.size.width)
      } else if catalog.groupedSections.isEmpty {
        emptyState
      } else {
        groupedList(width: geometryProxy.size.width)
      }
    }
  }

  func skeletonList(width: CGFloat) -> some View {
    ContentItemsListView(width: width, items: $catalog.items, onLoadMoreContent: { _ in
    }, onRefresh: {
      await catalog.refresh()
    }, navigationLinkProvider: { item in
      RouteLinkProvider().link(for: item)
    }, statusOverlay: { AnyView(MediaCardStatusBadge(item: $0)) })
  }

  func groupedList(width: CGFloat) -> some View {
    ScrollView {
      // Chips scroll with the content so the large title collapses.
      if !catalog.availableTypes.isEmpty {
        filterTabs
          .padding(.bottom, 4)
      }
      LazyVStack(spacing: 24, pinnedViews: [.sectionHeaders]) {
        ForEach(catalog.groupedSections) { section in
          Section {
            LazyVGrid(columns: gridLayout(width: width), spacing: 24) {
              ForEach(section.items, id: \.uniqueID) { historyItem in
                NavigationLink(value: RouteLinkProvider().link(for: historyItem.item)) {
                  HistoryItemCell(historyItem: historyItem)
                    .onAppear {
                      catalog.loadMoreContent(after: historyItem.item)
                    }
                }
                .buttonStyle(.plain)
                .contextMenu {
                  Button(role: .destructive) {
                    catalog.removeFromHistory(historyItem)
                  } label: {
                    Label("Remove from history".localized, systemImage: "trash")
                  }
                }
              }
            }
            .padding(.horizontal, 20)
          } header: {
            sectionHeader(section.title)
          }
        }
      }
      .padding(.top, 8)
    }
    .refreshable {
      await catalog.refresh()
    }
  }

  func sectionHeader(_ title: String) -> some View {
    HStack {
      Text(title)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(Color.KinoPub.text)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .glassCapsule()
      Spacer()
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 6)
  }

  var emptyState: some View {
    EmptyStateView(systemImage: "clock.arrow.circlepath", title: "No history yet".localized)
  }

  func gridLayout(width: CGFloat) -> [GridItem] {
    PosterGridLayout.columns(width: width, horizontalPadding: 20)
  }
}

// MARK: - Cell

/// Lightweight history grid cell mirroring the look of the shared content cell
/// (poster + localized/original titles). Built in-app because the shared
/// `ContentItemView` initializer is not public.
struct HistoryItemCell: View {
  let historyItem: HistoryItem

  private var mediaItem: MediaItem { historyItem.item }

  var body: some View {
    VStack(alignment: .center, spacing: 8) {
      Color.KinoPub.skeleton
        .aspectRatio(2.0 / 3.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .overlay {
          CachedAsyncImage(url: URL(string: mediaItem.posters.medium)) { image in
            image
              .resizable()
              .renderingMode(.original)
              .aspectRatio(contentMode: .fill)
          } placeholder: {
            Color.KinoPub.skeleton
          }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

      VStack(alignment: .center, spacing: 2) {
        Text(mediaItem.localizedTitle)
          .lineLimit(1)
          .font(.system(size: 16.0, weight: .medium))
          .foregroundStyle(Color.KinoPub.text)
        // For series, show the watched season/episode; otherwise the original title.
        Text(historyItem.episodeSubtitle ?? mediaItem.originalTitle)
          .lineLimit(1)
          .font(.system(size: 14.0, weight: .medium))
          .foregroundStyle(Color.KinoPub.subtitle)
      }
      .padding(.horizontal, 8)
    }
    .background(Color.clear)
  }
}

struct HistoryView_Previews: PreviewProvider {
  static var previews: some View {
    HistoryView(catalog: HistoryModel(itemsService: VideoContentServiceMock(),
                                      authState: AuthState(authService: AuthorizationServiceMock(), accessTokenService: AccessTokenServiceMock(), deviceService: DeviceServiceMock()),
                                      errorHandler: ErrorHandler()))
  }
}
