//
//  SearchView.swift
//  KinoPubAppleClient
//
//  Apple-TV-style search: a full-width field in the content (auto-focused), a live results LIST while
//  typing, and sectioned shelves (Top Results / Movies / TV Shows / Cast & Crew) once committed.
//  "Committed" = keyboard down (the field lost focus via Return or tapping a suggestion); editing the
//  query brings the live list back.
//

import SwiftUI
import KinoPubUI
import KinoPubBackend

/// Wrapper so a `MediaItem` can drive a `.sheet(item:)` (MediaItem isn't Identifiable on its own).
private struct BookmarkTarget: Identifiable {
  let item: MediaItem
  var id: Int { item.id }
}

struct SearchView: View {
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var authState: AuthState
  @EnvironmentObject var errorHandler: ErrorHandler
  @Environment(\.appContext) var appContext
  @StateObject private var model: SearchModel

  @FocusState private var searchFocused: Bool
  @State private var didAutoFocus = false
  @State private var bookmarkTarget: BookmarkTarget?
  /// True after the user commits a search (Return or tapping a suggestion) → show the sectioned
  /// layout. It is NOT tied to raw focus: incidental focus loss (opening a row's "…" menu, scrolling)
  /// must keep the live list, otherwise a row appears to vanish the moment you interact with it.
  @State private var committed = false

  init(model: @autoclosure @escaping () -> SearchModel) {
    _model = StateObject(wrappedValue: model())
  }

  private var trimmedQuery: String { model.query.trimmingCharacters(in: .whitespaces) }

  var body: some View {
    NavigationStack(path: $navigationState.searchRoutes) {
      WidthReader { width in
        ScrollView {
          if trimmedQuery.isEmpty {
            discoveryContent
          } else if committed {
            sections(width: width)
          } else {
            liveList
          }
        }
        // The field stays pinned at the very top while content scrolls *under* it (Apple-style),
        // and there's no "Search" page title — the glass field is the header.
        .safeAreaInset(edge: .top, spacing: 0) {
          searchField
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 8)
        }
      }
      .background(Color.KinoPub.background)
#if os(iOS)
      // No page title (the glass field is the header). Crucially we DON'T set an empty
      // navigationTitle — on iPad an empty title renders a tiny title-menu dot above the bar. Just
      // force the inline (thin) bar so the sidebar toggle stays but no large title area appears.
      .navigationBarTitleDisplayMode(.inline)
#endif
      .routeDestinations()
      .handleError(state: $errorHandler.state)
      // Re-focusing the field to edit drops back to the live list; losing focus to a menu/scroll
      // does NOT (that's what keeps a row from disappearing when you tap its "…").
      .onChange(of: searchFocused) { focused in if focused { committed = false } }
      .task { await model.loadGenres() }
      .onAppear {
        guard !didAutoFocus else { return }
        didAutoFocus = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { searchFocused = true }
      }
      .sheet(item: $bookmarkTarget) { target in
        BookmarkActionSheet(item: target.item, actionsService: appContext.actionsService)
      }
    }
  }

  // MARK: - Search field

  private var searchField: some View {
    HStack(spacing: 8) {
      Image(systemName: "magnifyingglass").foregroundStyle(Color.KinoPub.subtitle)
      TextField("Shows & Movies".localized, text: $model.query)
        .textFieldStyle(.plain)
        .foregroundStyle(Color.KinoPub.text)
        .focused($searchFocused)
        .submitLabel(.search)
        .autocorrectionDisabled()
#if os(iOS)
        .textInputAutocapitalization(.never)
#endif
        .onSubmit { committed = true; searchFocused = false } // commit → sections, keyboard down
      if !model.query.isEmpty {
        Button {
          model.query = ""
          searchFocused = true
        } label: {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(Color.KinoPub.subtitle)
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 12)
    // Fixed height so the row doesn't grow when the (taller) clear button appears on first keystroke.
    .frame(height: 44)
    .glassSearchField()
  }

  // MARK: - Discovery (empty query): recent + browse

  @ViewBuilder
  private var discoveryContent: some View {
    VStack(alignment: .leading, spacing: 24) {
      if !model.recentItems.isEmpty { recentSection }
      if !model.genres.isEmpty { browseSection }
      if model.recentItems.isEmpty && model.genres.isEmpty {
        EmptyStateView(systemImage: "magnifyingglass",
                       title: "Search".localized,
                       message: "Find movies, shows, actors and directors.".localized)
          .padding(.top, 80)
      }
    }
    .padding(16)
  }

  private var recentSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Recent").font(Font.KinoPub.subheader).foregroundStyle(Color.KinoPub.text)
        Spacer()
        Button("Clear") { model.clearRecents() }.foregroundStyle(Color.KinoPub.accent)
      }
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          ForEach(model.recentItems) { recent in
            NavigationLink(value: Route.detailsByID(recent.id)) { recentCard(recent) }
              .buttonStyle(.plain)
          }
        }
      }
    }
  }

  private var browseSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Browse").font(Font.KinoPub.subheader).foregroundStyle(Color.KinoPub.text)
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
        ForEach(model.genres, id: \.id) { genre in
          NavigationLink(value: Route.filteredCatalog(
            MediaItemsFilter(contentType: .movie, genres: [genre.id], countries: []),
            genre.title ?? "")) {
            browseCard(genre)
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private func browseCard(_ genre: MediaGenre) -> some View {
    ZStack(alignment: .bottomLeading) {
      CachedAsyncImage(url: URL(string: model.genrePosters[genre.id] ?? "")) { image in
        image.resizable().aspectRatio(contentMode: .fill)
      } placeholder: {
        LinearGradient(colors: [Color.KinoPub.accent.opacity(0.5), Color.black.opacity(0.6)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
      }
      LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
      Text(genre.title ?? "")
        .font(.system(size: 15, weight: .bold)).foregroundStyle(.white).padding(10)
    }
    .frame(height: 90)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  private func recentCard(_ recent: RecentSearchItem) -> some View {
    HStack(spacing: 12) {
      CachedAsyncImage(url: URL(string: recent.poster)) { image in
        image.resizable().aspectRatio(contentMode: .fill)
      } placeholder: { Color.KinoPub.skeleton }
      .frame(width: 100, height: 62).clipped()
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      VStack(alignment: .leading, spacing: 2) {
        Text(recent.title).font(.system(size: 15, weight: .medium))
          .foregroundStyle(Color.KinoPub.text).lineLimit(2)
        Text(recent.subtitle).font(.system(size: 13))
          .foregroundStyle(Color.KinoPub.subtitle).lineLimit(1)
      }
      .frame(width: 150, alignment: .leading)
    }
    .padding(8)
    .background(Color.white.opacity(0.06))
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  // MARK: - Live list (typing): matching recents as suggestions + result rows

  /// Recent searches whose title matches the current prefix — our stand-in for query suggestions
  /// (kino.pub has no autocomplete API).
  private var matchingRecents: [RecentSearchItem] {
    let q = trimmedQuery.lowercased()
    guard q.count >= 1 else { return [] }
    // Exclude anything already shown as a result row below, so an item never appears as both a
    // suggestion and a result (and never seems to "move" out of the list when opened).
    let resultIds = Set(model.allResults.map { $0.id })
    return model.recentItems
      .filter { $0.title.lowercased().contains(q) && !resultIds.contains($0.id) }
      .prefix(3).map { $0 }
  }

  @ViewBuilder
  private var liveList: some View {
    LazyVStack(alignment: .leading, spacing: 0) {
      ForEach(matchingRecents) { recent in
        Button {
          model.query = recent.title
          committed = true
          searchFocused = false
        } label: {
          HStack(spacing: 12) {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.KinoPub.accent)
            Text(recent.title).foregroundStyle(Color.KinoPub.text)
            Spacer()
          }
          .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        Divider().background(Color.white.opacity(0.06))
      }

      if model.searching && model.allResults.isEmpty {
        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
      } else if trimmedQuery.count >= 3 && model.allResults.isEmpty && !model.searching {
        EmptyStateView(systemImage: "magnifyingglass",
                       title: "Nothing found".localized,
                       message: "Try a different title, actor or director.".localized)
          .padding(.top, 60)
      } else {
        ForEach(model.allResults.prefix(25), id: \.id) { item in
          resultRow(item)
          Divider().background(Color.white.opacity(0.06)).padding(.leading, 16)
        }
      }
    }
  }

  private func resultRow(_ item: MediaItem) -> some View {
    HStack(spacing: 0) {
      NavigationLink(value: Route.details(item)) {
        HStack(spacing: 12) {
          CachedAsyncImage(url: URL(string: item.posters.small)) { image in
            image.resizable().aspectRatio(contentMode: .fill)
          } placeholder: { Color.KinoPub.skeleton }
          .frame(width: 46, height: 66).clipped()
          .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
          VStack(alignment: .leading, spacing: 3) {
            Text(item.localizedTitle).font(.system(size: 16))
              .foregroundStyle(Color.KinoPub.text).lineLimit(1)
            Text(metaLine(item)).font(.system(size: 13))
              .foregroundStyle(Color.KinoPub.subtitle).lineLimit(1)
          }
          Spacer(minLength: 8)
        }
      }
      .buttonStyle(.plain)
      .simultaneousGesture(TapGesture().onEnded { model.recordRecent(item) })

      Menu {
        Button {
          model.recordRecent(item)
          navigationState.searchRoutes.append(.details(item))
        } label: { Label("Open".localized, systemImage: "info.circle") }
        Button {
          bookmarkTarget = BookmarkTarget(item: item)
        } label: { Label("Add to bookmarks".localized, systemImage: "bookmark") }
      } label: {
        Image(systemName: "ellipsis")
          .foregroundStyle(Color.KinoPub.subtitle)
          .frame(width: 44, height: 44)
          .contentShape(Rectangle())
      }
    }
    .padding(.horizontal, 16).padding(.vertical, 8)
  }

  private func metaLine(_ item: MediaItem) -> String {
    var parts: [String] = []
    if let type = MediaType(rawValue: item.type)?.title { parts.append(type) }
    if let genre = item.genres.first?.title, !genre.isEmpty { parts.append(genre) }
    if item.year > 0 { parts.append("\(item.year)") }
    return parts.joined(separator: " · ")
  }

  // MARK: - Sections (committed): Top Results / Movies / TV Shows / Cast & Crew

  /// Movie/TV shelves ordered by how many results each has (so the dominant type leads, like Apple TV
  /// puts TV Shows first for "Shrinking" and Movies first for "Interstellar").
  private var orderedShelves: [(title: String, items: [MediaItem])] {
    var shelves: [(String, [MediaItem])] = []
    if !model.movieResults.isEmpty { shelves.append(("Movies".localized, model.movieResults)) }
    if !model.tvResults.isEmpty { shelves.append(("TV Shows".localized, model.tvResults)) }
    return shelves.sorted { $0.1.count > $1.1.count }
  }

  @ViewBuilder
  private func sections(width: CGFloat) -> some View {
    if model.searching && model.allResults.isEmpty {
      ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
    } else if model.allResults.isEmpty && model.people.isEmpty {
      EmptyStateView(systemImage: "magnifyingglass",
                     title: "Nothing found".localized,
                     message: "Try a different title, actor or director.".localized)
        .padding(.top, 80)
    } else {
      VStack(alignment: .leading, spacing: 28) {
        if !model.topResults.isEmpty { topResultsSection }
        ForEach(orderedShelves, id: \.title) { shelf in
          // ">" opens the full set on its own page (like Apple TV). Only when there's more than fits.
          MediaShelf(title: shelf.title,
                     showsChevron: shelf.items.count > 1,
                     onHeaderTap: { navigationState.searchRoutes.append(.mediaList(shelf.items, shelf.title)) }) {
            ForEach(shelf.items.prefix(18), id: \.id) { item in
              NavigationLink(value: Route.details(item)) {
                PosterCard(imageURL: item.posters.medium, title: item.localizedTitle, width: 130)
              }
              .buttonStyle(.plain)
            }
          }
        }
        if !model.people.isEmpty { castCrewSection }
      }
      .padding(.vertical, 8)
    }
  }

  private var topResultsSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Top Results".localized)
        .font(.system(size: 22, weight: .bold)).foregroundStyle(Color.KinoPub.text)
        .padding(.horizontal, 20)
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          ForEach(model.topResults, id: \.id) { item in
            NavigationLink(value: Route.details(item)) { topResultCard(item) }
              .buttonStyle(.plain)
          }
        }
        .padding(.horizontal, 20)
      }
    }
  }

  private func topResultCard(_ item: MediaItem) -> some View {
    HStack(spacing: 12) {
      CachedAsyncImage(url: URL(string: item.posters.small)) { image in
        image.resizable().aspectRatio(contentMode: .fill)
      } placeholder: { Color.KinoPub.skeleton }
      .frame(width: 60, height: 88).clipped()
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      VStack(alignment: .leading, spacing: 4) {
        Text(item.localizedTitle).font(.system(size: 16, weight: .semibold))
          .foregroundStyle(Color.KinoPub.text).lineLimit(2)
        Text(metaLine(item)).font(.system(size: 13))
          .foregroundStyle(Color.KinoPub.subtitle).lineLimit(1)
      }
      .frame(width: 200, alignment: .leading)
    }
    .padding(10)
    .background(Color.white.opacity(0.06))
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  private var castCrewSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Button {
        // Open the full people list (like a film page's Cast & Crew / Apple TV), not a film search.
        navigationState.searchRoutes.append(.castCrew(model.people, "Cast & Crew".localized))
      } label: {
        HStack(spacing: 4) {
          Text("Cast & Crew".localized)
            .font(.system(size: 22, weight: .bold)).foregroundStyle(Color.KinoPub.text)
          Image(systemName: "chevron.right")
            .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.KinoPub.subtitle)
        }
      }
      .buttonStyle(.plain)
      .padding(.horizontal, 20)
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 16) {
          ForEach(model.people) { person in
            NavigationLink(value: Route.personSearch(person.name, person.searchField, person.displayName)) {
              CastAvatarView(imageURL: ActorImageProvider.photoURLString(for: person.name),
                             name: person.displayName,
                             role: person.roleLabel)
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.horizontal, 20)
      }
    }
  }
}

private extension View {
  /// Frosted glass background for the sticky search field (content scrolling underneath blurs
  /// through it). The glass is a *background* layer — applying `glassEffect` to the field itself
  /// makes it swallow taps (the clear button stops working), so we keep the field's controls in
  /// front and the material behind.
  func glassSearchField() -> some View {
    let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
    return self
      .background(shape.fill(.ultraThinMaterial))
      .overlay(shape.strokeBorder(Color.white.opacity(0.10)).allowsHitTesting(false))
  }
}

// MARK: - Bookmark action sheet ("Add to bookmarks" from a result row)

private struct BookmarkActionSheet: View {
  let item: MediaItem
  let actionsService: UserActionsService
  @Environment(\.dismiss) private var dismiss
  @State private var folders: [Bookmark] = []
  @State private var inFolders: Set<Int> = []
  @State private var loading = true

  var body: some View {
    NavigationStack {
      List {
        if item.isSeries {
          Section {
            Button {
              Task { try? await actionsService.toggleWatchlist(id: item.id); dismiss() }
            } label: {
              Label("Add to watchlist".localized, systemImage: "plus.rectangle.on.rectangle")
            }
          }
        }
        Section(header: Text("Bookmark folders".localized)) {
          if loading {
            ProgressView()
          } else if folders.isEmpty {
            Text("No bookmark folders yet.".localized).foregroundStyle(Color.KinoPub.subtitle)
          } else {
            ForEach(folders) { folder in
              Button {
                let isIn = inFolders.contains(folder.id)
                if isIn { inFolders.remove(folder.id) } else { inFolders.insert(folder.id) }
                Task { try? await actionsService.toggleBookmark(itemId: item.id, folderId: folder.id) }
              } label: {
                HStack {
                  Text(folder.title).foregroundStyle(Color.KinoPub.text)
                  Spacer()
                  if inFolders.contains(folder.id) {
                    Image(systemName: "checkmark").foregroundStyle(Color.KinoPub.accent)
                  }
                }
              }
            }
          }
        }
      }
      .scrollContentBackground(.hidden)
      .background(Color.KinoPub.background)
      .navigationTitle(item.localizedTitle)
#if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
#endif
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("Done".localized) { dismiss() } }
      }
      .task {
        folders = (try? await actionsService.fetchBookmarks()) ?? []
        inFolders = Set((try? await actionsService.foldersContaining(itemId: item.id)) ?? [])
        loading = false
      }
    }
  }
}

/// A "see all" grid for a search section (Movies / TV Shows), showing the already-loaded results.
struct MediaListGridView: View {
  let items: [MediaItem]
  let title: String

  var body: some View {
    WidthReader { width in
      ScrollView {
        LazyVGrid(columns: PosterGridLayout.columns(width: width), spacing: 16) {
          ForEach(items, id: \.id) { item in
            NavigationLink(value: Route.details(item)) {
              PosterCard(imageURL: item.posters.medium, title: item.localizedTitle, width: nil)
            }
#if os(macOS)
            .buttonStyle(.plain)
#endif
          }
        }
        .padding(16)
      }
    }
    .kinoScreen(title)
  }
}

/// Full "Cast & Crew" people list opened from a committed search — mirrors the people grid on a film
/// page / Apple TV. Each person opens their filmography (a person search), not a film-title search.
struct SearchCastCrewView: View {
  let people: [SearchPerson]
  let title: String

  private let columns = [GridItem(.adaptive(minimum: 100), spacing: 14, alignment: .top)]

  var body: some View {
    ScrollView {
      LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
        ForEach(people) { person in
          NavigationLink(value: Route.personSearch(person.name, person.searchField, person.displayName)) {
            CastAvatarView(imageURL: ActorImageProvider.photoURLString(for: person.name),
                           name: person.displayName,
                           role: person.roleLabel,
                           diameter: 80)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(16)
    }
    .kinoScreen(title)
  }
}

struct SearchView_Previews: PreviewProvider {
  @StateObject static var navState = NavigationState()

  static var previews: some View {
    SearchView(model: SearchModel(itemsService: VideoContentServiceMock(),
                                  authState: AuthState(authService: AuthorizationServiceMock(), accessTokenService: AccessTokenServiceMock(), deviceService: DeviceServiceMock()),
                                  errorHandler: ErrorHandler()))
      .environmentObject(navState)
  }
}
