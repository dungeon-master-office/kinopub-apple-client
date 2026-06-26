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

  @State private var heroIndex: Int = 0
  @State private var isHeroInteracting: Bool = false
  private let heroTimer = Timer.publish(every: 6, on: .main, in: .common).autoconnect()

  init(model: @autoclosure @escaping () -> HomeModel) {
    _model = StateObject(wrappedValue: model())
  }

  var body: some View {
    NavigationStack(path: $navigationState.homeRoutes) {
      ScrollView(.vertical) {
        LazyVStack(alignment: .leading, spacing: 28) {
          heroSection
          if model.continueWatchingLoading {
            continueWatchingPlaceholderShelf
          } else if !model.continueWatching.isEmpty {
            continueWatchingShelf
          }
          ForEach(model.shelves) { shelf in
            shelfView(shelf)
          }
        }
        .padding(.bottom, 24)
      }
      .background(Color.KinoPub.background)
      .navigationTitle("Home")
      // iOS 26: hero bleeds under the transparent glass bar. Pre-26: blurred bar + restored safe area.
      .heroNavBar()
      .task {
        await model.fetchData()
      }
      .routeDestinations()
      .handleError(state: $errorHandler.state)
    }
  }

  private var heroHeight: CGFloat { 460 }

  @ViewBuilder
  private var heroSection: some View {
    if model.featured.isEmpty {
      HeroBackdrop(imageURL: nil, height: heroHeight) { EmptyView() }
    } else {
#if os(iOS)
      TabView(selection: $heroIndex) {
        ForEach(Array(model.featured.enumerated()), id: \.element.id) { index, item in
          heroPage(item).tag(index)
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .always))
      .frame(height: heroHeight)
      // Don't auto-advance while the user is swiping the gallery (resume shortly after).
      .simultaneousGesture(
        DragGesture()
          .onChanged { _ in isHeroInteracting = true }
          .onEnded { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) { isHeroInteracting = false }
          }
      )
      .onReceive(heroTimer) { _ in
        guard !isHeroInteracting, model.featured.count > 1 else { return }
        withAnimation { heroIndex = (heroIndex + 1) % model.featured.count }
      }
#else
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 16) {
          ForEach(model.featured) { heroPage($0).frame(width: 820) }
        }
      }
      .frame(height: heroHeight)
#endif
    }
  }

  @ViewBuilder
  private func heroPage(_ hero: MediaItem) -> some View {
    NavigationLink(value: Route.details(hero)) {
      HeroBackdrop(imageURL: hero.posters.wide ?? hero.posters.big, height: heroHeight) {
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
        .padding(.bottom, 20)
      }
    }
    .buttonStyle(PlainButtonStyle())
  }

  @ViewBuilder
  private var continueWatchingPlaceholderShelf: some View {
    MediaShelf(title: "Continue Watching".localized) {
      ForEach(0..<6, id: \.self) { _ in
        ContinueWatchingCard.placeholder()
      }
    }
  }

  private var continueWatchingShelf: some View {
    MediaShelf(title: "Continue Watching".localized) {
      ForEach(model.continueWatching) { entry in
        NavigationLink(value: Route.details(entry.item)) {
          ContinueWatchingCard(imageURL: entry.item.posters.wide ?? entry.item.posters.big,
                               title: entry.item.localizedTitle,
                               subtitle: entry.subtitle,
                               progress: entry.progress)
          .overlay(alignment: .topTrailing) {
            MediaCardStatusBadge(item: entry.item, showsWatched: false)
          }
        }
#if os(macOS)
        .buttonStyle(PlainButtonStyle())
#endif
      }
    }
  }

  @ViewBuilder
  private func shelfView(_ shelf: HomeModel.Shelf) -> some View {
    MediaShelf(title: shelf.title,
               onHeaderTap: shelf.filter.map { filter in
                 { navigationState.homeRoutes.append(.filteredCatalog(filter, shelf.title)) }
               }) {
      ForEach(shelf.items) { item in
        NavigationLink(value: Route.details(item)) {
          PosterCard(imageURL: item.posters.medium,
                     title: item.localizedTitle,
                     imdbRating: item.imdbRating,
                     kinopoiskRating: item.kinopoiskRating)
          .overlay(alignment: .topTrailing) { MediaCardStatusBadge(item: item) }
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
