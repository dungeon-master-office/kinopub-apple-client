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
  // Local path: "New episodes" and "Watching" are two top-level screens — each owns its own
  // navigation stack so they never share one path binding (which would crash on switch).
  @State private var path: [Route] = []
  @Environment(\.sectionEmbedded) private var sectionEmbedded

  init(model: @autoclosure @escaping () -> WatchingModel) {
    _model = StateObject(wrappedValue: model())
  }

  var body: some View {
    if sectionEmbedded {
      sectionContent
    } else {
      NavigationStack(path: $path) {
        sectionContent.routeDestinations()
      }
    }
  }

  private var sectionContent: some View {
    // WidthReader gives the responsive grid the real width; the chips are the first scrolling
    // element so the large title collapses on scroll.
    WidthReader { width in
      ScrollView {
        if model.tab == .newEpisodes {
          episodesTypePicker
            .padding(.bottom, 4)
        }
        gridBody(width: width)
      }
      .refreshable { await model.refresh() }
    }
    .kinoScreen((model.tab == .newEpisodes ? "New episodes" : "Watching").localized)
    .task {
      await model.fetchItems()
    }
    .handleError(state: $errorHandler.state)
  }

  @ViewBuilder
  private func gridBody(width: CGFloat) -> some View {
    if model.isLoading {
      skeletonGrid(width: width)
    } else if model.serials.isEmpty {
      EmptyStateView(systemImage: "play.tv", title: "No series here yet".localized)
        .frame(minHeight: 320)
    } else {
      serialsGrid(width: width)
    }
  }

  var episodesTypePicker: some View {
    FilterChipBar(items: WatchingEpisodesType.allCases.map {
                    FilterChipItem(id: $0.rawValue, title: $0.title.localized)
                  },
                  selection: Binding(
                    get: { model.episodesType.rawValue },
                    set: { if let type = WatchingEpisodesType(rawValue: $0) {
                      model.select(episodesType: type)
                    } }
                  ))
  }

  private func serialsGrid(width: CGFloat) -> some View {
    LazyVGrid(columns: PosterGridLayout.columns(width: width, horizontalPadding: 20), spacing: 24) {
      ForEach(model.serials) { serial in
        NavigationLink(value: Route.detailsByID(serial.id)) {
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

  private func skeletonGrid(width: CGFloat) -> some View {
    LazyVGrid(columns: PosterGridLayout.columns(width: width, horizontalPadding: 20), spacing: 24) {
      ForEach(0..<12, id: \.self) { _ in
        PosterCard.placeholder(width: 150)
      }
    }
    .padding(.horizontal, 20)
    .padding(.top, 8)
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
