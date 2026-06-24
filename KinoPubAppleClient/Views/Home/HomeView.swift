//
//  HomeView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 24.06.2026.
//

import SwiftUI
import KinoPubUI
import KinoPubBackend

struct HomeView: View {
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var errorHandler: ErrorHandler
  @EnvironmentObject var authState: AuthState
  @Environment(\.appContext) var appContext
  @StateObject private var model: HomeModel

  init(model: @autoclosure @escaping () -> HomeModel) {
    _model = StateObject(wrappedValue: model())
  }

  var body: some View {
    NavigationStack(path: $navigationState.mainRoutes) {
      ScrollView(.vertical) {
        LazyVStack(alignment: .leading, spacing: 28) {
          heroSection
          ForEach(model.shelves) { shelf in
            shelfView(shelf)
          }
        }
        .padding(.bottom, 24)
      }
      .background(Color.KinoPub.background)
      .navigationTitle("Home")
      .task {
        await model.fetchData()
      }
      .navigationDestination(for: MainRoutes.self) { route in
        switch route {
        case .details(let item):
          MediaItemView(model: MediaItemModel(mediaItemId: item.id,
                                              itemsService: appContext.contentService,
                                              downloadManager: appContext.downloadManager,
                                              linkProvider: MainRoutesLinkProvider(),
                                              errorHandler: errorHandler))
        case .player(let item):
          PlayerView(manager: PlayerManager(playItem: item,
                                            watchMode: .media,
                                            downloadedFilesDatabase: appContext.downloadedFilesDatabase,
                                            actionsService: appContext.actionsService))
        case .trailerPlayer(let item):
          PlayerView(manager: PlayerManager(playItem: item,
                                            watchMode: .trailer,
                                            downloadedFilesDatabase: appContext.downloadedFilesDatabase,
                                            actionsService: appContext.actionsService))
        case .seasons(let seasons):
          SeasonsView(model: SeasonsModel(seasons: seasons, linkProvider: MainRoutesLinkProvider()))
        case .season(let season):
          SeasonView(model: SeasonModel(season: season, linkProvider: MainRoutesLinkProvider()))
        }
      }
      .handleError(state: $errorHandler.state)
    }
  }

  @ViewBuilder
  private var heroSection: some View {
    if let hero = model.hero {
      NavigationLink(value: MainRoutes.details(hero)) {
        HeroBackdrop(imageURL: hero.posters.wide ?? hero.posters.big, height: 460) {
          VStack(alignment: .leading, spacing: 10) {
            Text(hero.localizedTitle)
              .font(.system(size: 34, weight: .bold))
              .foregroundStyle(.white)
              .lineLimit(2)
            Text(hero.genres.compactMap { $0.title }.joined(separator: " · "))
              .font(.subheadline)
              .foregroundStyle(.white.opacity(0.85))
              .lineLimit(1)
            Label("Details", systemImage: "info.circle")
              .font(.headline)
              .foregroundStyle(.white)
              .padding(.horizontal, 18)
              .padding(.vertical, 10)
              .background(Color.white.opacity(0.18))
              .clipShape(Capsule())
              .padding(.top, 4)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .buttonStyle(PlainButtonStyle())
    }
  }

  @ViewBuilder
  private func shelfView(_ shelf: HomeModel.Shelf) -> some View {
    let items = shelf.ranked ? Array(shelf.items.prefix(10)) : shelf.items
    MediaShelf(title: shelf.title) {
      ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
        NavigationLink(value: MainRoutes.details(item)) {
          PosterCard(imageURL: item.posters.medium,
                     rank: shelf.ranked ? (index + 1) : nil)
        }
#if os(macOS)
        .buttonStyle(PlainButtonStyle())
#endif
      }
    }
  }
}

struct HomeView_Previews: PreviewProvider {
  static var previews: some View {
    HomeView(model: HomeModel(itemsService: VideoContentServiceMock(),
                              authState: AuthState(authService: AuthorizationServiceMock(), accessTokenService: AccessTokenServiceMock()),
                              errorHandler: ErrorHandler()))
  }
}
