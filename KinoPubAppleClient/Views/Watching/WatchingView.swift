//
//  WatchingView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 24.06.2026.
//

import SwiftUI
import KinoPubUI
import KinoPubBackend
import SkeletonUI

struct WatchingView: View {
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var authState: AuthState
  @EnvironmentObject var errorHandler: ErrorHandler
  @Environment(\.appContext) var appContext
  @StateObject private var model: WatchingModel

  init(model: @autoclosure @escaping () -> WatchingModel) {
    _model = StateObject(wrappedValue: model())
  }

  var body: some View {
    NavigationStack(path: $navigationState.watchingRoutes) {
      VStack(spacing: 0) {
        filterPicker
        content
      }
      .navigationTitle("Watching".localized)
      #if !os(macOS)
      .navigationBarTitleDisplayMode(.large)
      #endif
      .background(Color.KinoPub.background)
      .task {
        await model.fetchItems()
      }
      .navigationDestination(for: WatchingRoutes.self) { route in
        switch route {
        case .details(let id):
          MediaItemView(model: MediaItemModel(mediaItemId: id,
                                              itemsService: appContext.contentService,
                                              downloadManager: appContext.downloadManager,
                                              linkProvider: WatchingRoutesLinkProvider(),
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
          SeasonsView(model: SeasonsModel(seasons: seasons, linkProvider: WatchingRoutesLinkProvider()))
        case .season(let season):
          SeasonView(model: SeasonModel(season: season, linkProvider: WatchingRoutesLinkProvider()))
        }
      }
      .handleError(state: $errorHandler.state)
    }
  }

  var filterPicker: some View {
    FilterChipBar(items: WatchingFilter.allCases.map {
                    FilterChipItem(id: "\($0.rawValue)", title: $0.title.localized)
                  },
                  selection: Binding(
                    get: { "\(model.filter.rawValue)" },
                    set: { if let raw = Int($0), let filter = WatchingFilter(rawValue: raw) {
                      model.select(filter: filter)
                    } }
                  ))
  }

  @ViewBuilder
  var content: some View {
    if model.isLoading {
      Spacer()
      ProgressView()
        .tint(Color.KinoPub.accent)
      Spacer()
    } else if model.serials.isEmpty {
      Spacer()
      Text("No series here yet")
        .font(.system(size: 16.0, weight: .medium))
        .foregroundStyle(Color.KinoPub.subtitle)
      Spacer()
    } else {
      serialsGrid
    }
  }

  var serialsGrid: some View {
    ScrollView {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16, alignment: .top)], spacing: 24) {
        ForEach(model.serials) { serial in
          NavigationLink(value: WatchingRoutes.details(serial.id)) {
            WatchingSerialView(serial: serial)
          }
          #if os(macOS)
          .buttonStyle(PlainButtonStyle())
          #endif
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 8)
    }
    .refreshable {
      await model.refresh()
    }
  }
}

struct WatchingSerialView: View {
  var serial: WatchingSerial

  var body: some View {
    VStack(alignment: .center) {
      ZStack(alignment: .topTrailing) {
        image
        if let new = serial.new, new > 0 {
          newBadge(count: new)
        }
      }
      VStack(alignment: .center) {
        Text(serial.localizedTitle)
          .lineLimit(1)
          .font(.system(size: 16.0, weight: .medium))
          .foregroundStyle(Color.KinoPub.text)
        Text(serial.originalTitle)
          .lineLimit(1)
          .font(.system(size: 14.0, weight: .medium))
          .foregroundStyle(Color.KinoPub.subtitle)
      }
      .padding(.horizontal, 8)
    }
    .background(Color.clear)
  }

  var image: some View {
    // Match the common grid card (ContentItemView): 2:3 poster filling the column width.
    Color.KinoPub.skeleton
      .aspectRatio(2.0 / 3.0, contentMode: .fit)
      .frame(maxWidth: .infinity)
      .overlay {
        CachedAsyncImage(url: URL(string: serial.posters.medium)) { image in
          image
            .resizable()
            .renderingMode(.original)
            .aspectRatio(contentMode: .fill)
        } placeholder: {
          Color.KinoPub.skeleton
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  func newBadge(count: Int) -> some View {
    Text("+\(count)")
      .font(.system(size: 13.0, weight: .bold))
      .foregroundStyle(Color.white)
      .padding(.horizontal, 7)
      .padding(.vertical, 3)
      .background(Color.KinoPub.accent)
      .clipShape(Capsule())
      .padding(6)
  }
}

struct WatchingView_Previews: PreviewProvider {
  static var previews: some View {
    WatchingView(model: WatchingModel(itemsService: VideoContentServiceMock(),
                                      authState: AuthState(authService: AuthorizationServiceMock(), accessTokenService: AccessTokenServiceMock()),
                                      errorHandler: ErrorHandler()))
  }
}
