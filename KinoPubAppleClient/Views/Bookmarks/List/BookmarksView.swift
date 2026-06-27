//
//  BookmarksView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 22.07.2023.
//

import SwiftUI
import KinoPubUI
import SkeletonUI

struct BookmarksView: View {
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var authState: AuthState
  @EnvironmentObject var errorHandler: ErrorHandler
  @Environment(\.appContext) var appContext
  @StateObject private var catalog: BookmarksCatalog
  @Environment(\.sectionEmbedded) private var sectionEmbedded

  init(catalog: @autoclosure @escaping () -> BookmarksCatalog) {
    _catalog = StateObject(wrappedValue: catalog())
  }

  var body: some View {
    if sectionEmbedded {
      sectionContent
    } else {
      NavigationStack(path: $navigationState.bookmarksRoutes) {
        sectionContent.routeDestinations()
      }
    }
  }

  private var sectionContent: some View {
    bookmarksList
      .kinoScreen("Bookmarks".localized)
      .refreshable(action: catalog.refresh)
      .handleError(state: $errorHandler.state)
  }
  
  var bookmarksList: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 28) {
        ForEach(catalog.items) { bookmark in
          MediaShelf(title: bookmark.title,
                     onHeaderTap: {
                       navigationState.bookmarksRoutes.append(Route.bookmark(bookmark))
                     }) {
            if let items = catalog.folderItems[bookmark.id] {
              ForEach(items) { item in
                NavigationLink(value: Route.details(item)) {
                  PosterCard(imageURL: item.posters.medium,
                             title: item.localizedTitle,
                             imdbRating: item.imdbRating,
                             kinopoiskRating: item.kinopoiskRating)
                  .overlay(alignment: .topTrailing) { MediaCardStatusBadge(item: item) }
                }
                .buttonStyle(.plain)
              }
            } else {
              // Loading placeholder shelf.
              ForEach(0..<4, id: \.self) { _ in
                PosterCard.placeholder()
              }
            }
          }
        }
      }
      .padding(.vertical, 16)
    }
    .background(Color.KinoPub.background)
  }
}

struct BookmarksView_Previews: PreviewProvider {
  static var previews: some View {
    BookmarksView(catalog: BookmarksCatalog(itemsService: VideoContentServiceMock(),
                                            authState: AuthState(authService: AuthorizationServiceMock(), accessTokenService: AccessTokenServiceMock(), deviceService: DeviceServiceMock()),
                                            errorHandler: ErrorHandler()))
  }
}
