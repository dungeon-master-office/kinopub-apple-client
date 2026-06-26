//
//  SearchView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 24.06.2026.
//

import SwiftUI
import KinoPubUI
import KinoPubBackend

struct SearchView: View {
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var authState: AuthState
  @EnvironmentObject var errorHandler: ErrorHandler
  @Environment(\.appContext) var appContext
  @StateObject private var model: SearchModel

  private let browseColumns = [GridItem(.adaptive(minimum: 220), spacing: 16)]
  private let resultsColumns = [GridItem(.adaptive(minimum: 130), spacing: 16)]

  init(model: @autoclosure @escaping () -> SearchModel) {
    _model = StateObject(wrappedValue: model())
  }

  var body: some View {
    NavigationStack(path: $navigationState.searchRoutes) {
      ScrollView {
        if model.query.trimmingCharacters(in: .whitespaces).isEmpty {
          discoveryContent
        } else if model.allResults.isEmpty && !model.searching {
          EmptyStateView(systemImage: "magnifyingglass",
                         title: "Nothing found".localized,
                         message: "Try a different title, actor or director.".localized)
            .padding(.top, 80)
        } else {
          resultsContent
        }
      }
      .searchable(text: $model.query, placement: .automatic, prompt: "Shows & Movies")
      .navigationTitle("Search")
      .background(Color.KinoPub.background)
      .task {
        await model.loadGenres()
      }
      .routeDestinations()
      .handleError(state: $errorHandler.state)
    }
  }

  // MARK: - Discovery (empty query)

  var discoveryContent: some View {
    VStack(alignment: .leading, spacing: 24) {
      if !model.recentItems.isEmpty {
        recentSection
      }
      browseSection
    }
    .padding(16)
  }

  var recentSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Recent")
          .font(Font.KinoPub.subheader)
          .foregroundStyle(Color.KinoPub.text)
        Spacer()
        Button("Clear") {
          model.clearRecents()
        }
        .foregroundStyle(Color.KinoPub.accent)
      }

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          ForEach(model.recentItems) { recent in
            NavigationLink(value: Route.details(MediaItem.mock(id: recent.id))) {
              recentCard(recent)
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
  }

  private func recentCard(_ recent: RecentSearchItem) -> some View {
    HStack(spacing: 12) {
      CachedAsyncImage(url: URL(string: recent.poster)) { image in
        image.resizable().aspectRatio(contentMode: .fill)
      } placeholder: {
        Color.KinoPub.skeleton
      }
      .frame(width: 100, height: 62)
      .clipped()
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

      VStack(alignment: .leading, spacing: 2) {
        Text(recent.title)
          .font(.system(size: 15, weight: .medium))
          .foregroundStyle(Color.KinoPub.text)
          .lineLimit(2)
        Text(recent.subtitle)
          .font(.system(size: 13))
          .foregroundStyle(Color.KinoPub.subtitle)
          .lineLimit(1)
      }
      .frame(width: 150, alignment: .leading)
    }
    .padding(8)
    .background(Color.white.opacity(0.06))
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  var browseSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Browse")
        .font(Font.KinoPub.subheader)
        .foregroundStyle(Color.KinoPub.text)

      LazyVGrid(columns: browseColumns, spacing: 16) {
        if model.genres.isEmpty {
          ForEach(MediaType.allCases) { type in
            NavigationLink(value: Route.genre(0, type.title)) {
              BrowseCategoryCard(title: type.title)
            }
#if os(macOS)
            .buttonStyle(.plain)
#endif
          }
        } else {
          ForEach(model.genres, id: \.id) { genre in
            NavigationLink(value: Route.genre(genre.id, genre.title)) {
              BrowseCategoryCard(title: genre.title, imageURL: model.genrePosters[genre.id])
            }
#if os(macOS)
            .buttonStyle(.plain)
#endif
          }
        }
      }
    }
  }

  // MARK: - Results (non-empty query)

  var resultsContent: some View {
    VStack(alignment: .leading, spacing: 12) {
      scopeTabBar
      if let people = matchedPeopleForScope, !people.isEmpty {
        peopleStrip(people)
        Divider().background(Color.white.opacity(0.08))
      }
      LazyVGrid(columns: resultsColumns, spacing: 16) {
        ForEach(model.results(for: model.scope), id: \.id) { item in
          if item.skeleton ?? false {
            PosterCard.placeholder()
          } else {
            NavigationLink(value: Route.details(item)) {
              PosterCard(imageURL: item.posters.medium, title: item.localizedTitle)
            }
#if os(macOS)
            .buttonStyle(.plain)
#endif
            .simultaneousGesture(TapGesture().onEnded {
              model.recordRecent(item)
            })
          }
        }
      }
    }
    .padding(16)
  }

  // MARK: - Scope tabs (All / Titles / Actors / Directors), like the kino.pub web search

  @ViewBuilder
  private var scopeTabBar: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(SearchScope.allCases) { scope in
          scopeTab(scope)
        }
      }
    }
  }

  private func scopeTab(_ scope: SearchScope) -> some View {
    let isSelected = model.scope == scope
    return Button {
      model.scope = scope
    } label: {
      HStack(spacing: 6) {
        Text(scope.title.localized)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(isSelected ? Color.white : Color.KinoPub.text)
        Text("\(model.count(for: scope))")
          .font(.system(size: 11, weight: .bold))
          .monospacedDigit()
          .padding(.horizontal, 6)
          .padding(.vertical, 1)
          .background(Capsule().fill(isSelected ? Color.white.opacity(0.25) : Color.KinoPub.accent.opacity(0.22)))
          .foregroundStyle(isSelected ? Color.white : Color.KinoPub.accent)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(Capsule().fill(isSelected ? Color.KinoPub.accent : Color.white.opacity(0.1)))
    }
    .buttonStyle(.plain)
  }

  // MARK: - Matched people (circles above the Actors / Directors results)

  /// The people matched for the current tab, or nil for tabs that don't show a people strip.
  private var matchedPeopleForScope: [TMDBPerson]? {
    switch model.scope {
    case .cast: return model.matchedActors
    case .director: return model.matchedDirectors
    case .all, .title: return nil
    }
  }

  private func peopleStrip(_ people: [TMDBPerson]) -> some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(alignment: .top, spacing: 14) {
        ForEach(people) { person in
          NavigationLink(value: Route.personSearch(person.name,
                                                   model.scope.field ?? "cast",
                                                   person.name)) {
            VStack(spacing: 6) {
              personAvatar(person.imageURL)
              Text(person.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.KinoPub.text)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 72)
            }
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.vertical, 2)
    }
  }

  private func personAvatar(_ url: URL?) -> some View {
    CachedAsyncImage(url: url) { image in
      image.resizable().scaledToFill()
    } placeholder: {
      ZStack {
        Color.KinoPub.skeleton
        Image(systemName: "person.fill").foregroundStyle(Color.KinoPub.subtitle)
      }
    }
    .frame(width: 64, height: 64)
    .clipShape(Circle())
  }

}

struct SearchView_Previews: PreviewProvider {
  @StateObject static var navState = NavigationState()

  static var previews: some View {
    SearchView(model: SearchModel(itemsService: VideoContentServiceMock(),
                                  authState: AuthState(authService: AuthorizationServiceMock(), accessTokenService: AccessTokenServiceMock()),
                                  errorHandler: ErrorHandler()))
      .environmentObject(navState)
  }
}
