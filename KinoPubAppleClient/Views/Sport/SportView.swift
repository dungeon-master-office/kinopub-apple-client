//
//  SportView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 24.06.2026.
//

import SwiftUI
import KinoPubUI
import KinoPubBackend

struct SportView: View {
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var authState: AuthState
  @EnvironmentObject var errorHandler: ErrorHandler
  @Environment(\.appContext) var appContext
#if os(iOS)
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif
  @StateObject private var model: SportModel
  @State private var selectedChannel: TVChannel?

  // Compact (iPhone) grid — small tiles, ~2× more per row than the old layout.
  private let gridColumns = [GridItem(.adaptive(minimum: 140), spacing: 14, alignment: .top)]

  init(model: @autoclosure @escaping () -> SportModel) {
    _model = StateObject(wrappedValue: model())
  }

  /// Wide screens (iPad / macOS) get a master list + inline player; iPhone gets a grid.
  private var isWide: Bool {
#if os(macOS)
    return true
#else
    return horizontalSizeClass == .regular
#endif
  }

  var body: some View {
    NavigationStack {
      content
        .navigationTitle("Sport")
        .background(Color.KinoPub.background)
        .task { await model.fetchChannels() }
        .refreshable { await model.refresh() }
        .navigationDestination(for: TVChannel.self) { channel in
          PlayerView(manager: PlayerManager(playItem: channel,
                                            watchMode: .media,
                                            downloadedFilesDatabase: appContext.downloadedFilesDatabase,
                                            actionsService: appContext.actionsService))
        }
        .handleError(state: $errorHandler.state)
    }
  }

  @ViewBuilder
  private var content: some View {
    if model.isLoading {
      loading
    } else if model.channels.isEmpty {
      emptyState
    } else if isWide {
      wideLayout
    } else {
      compactGrid
    }
  }

  // MARK: - Compact (iPhone): smaller grid, tap opens the modal player

  private var compactGrid: some View {
    ScrollView {
      LazyVGrid(columns: gridColumns, spacing: 16) {
        ForEach(model.channels) { channel in
          NavigationLink(value: channel) {
            LiveChannelCard(channel: channel)
          }
        }
      }
      .padding(16)
    }
  }

  // MARK: - Wide (iPad / macOS): channel list + inline 16:9 player

  private var wideLayout: some View {
    GeometryReader { geo in
      if geo.size.width >= 700 {
        // Roomy: list beside the player.
        HStack(spacing: 0) {
          channelList
            .frame(width: 320)
          Divider()
          VStack(spacing: 0) {
            playerHeader
            Spacer(minLength: 0)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      } else {
        // Narrow: player on top, list below.
        VStack(spacing: 0) {
          playerHeader
          Divider()
          channelList
        }
      }
    }
    .onAppear {
      if selectedChannel == nil { selectedChannel = model.channels.first }
    }
  }

  // Native list: the whole row is selectable (single-selection binding).
  private var channelList: some View {
    List(selection: $selectedChannel) {
      ForEach(model.channels) { channel in
        ChannelRow(channel: channel, isSelected: channel.id == selectedChannel?.id)
          .tag(channel)
          .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
          .listRowBackground(Color.clear)
          .listRowSeparator(.hidden)
      }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .background(Color.KinoPub.background)
  }

  @ViewBuilder
  private var playerHeader: some View {
    if let channel = selectedChannel, let url = URL(string: channel.stream) {
      VStack(alignment: .leading, spacing: 12) {
        InlinePlayerView(url: url)
          .id(channel.id)
          .frame(maxWidth: 900)
        Text(channel.title)
          .font(.system(size: 20, weight: .bold))
          .foregroundStyle(Color.KinoPub.text)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(16)
    } else {
      VStack {
        Spacer()
        Image(systemName: "play.tv")
          .font(.system(size: 44))
          .foregroundStyle(Color.KinoPub.subtitle)
        Spacer()
      }
      .frame(maxWidth: .infinity)
    }
  }

  // MARK: - States

  private var loading: some View {
    VStack {
      Spacer()
      ProgressView().tint(Color.KinoPub.accent)
      Spacer()
    }
    .frame(maxWidth: .infinity)
  }

  private var emptyState: some View {
    EmptyStateView(systemImage: "sportscourt", title: "No live broadcasts right now".localized)
  }
}

/// Compact tile for the iPhone grid: channel logo + title.
struct LiveChannelCard: View {
  let channel: TVChannel

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      ChannelArtwork(logo: channel.logo)
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
      Text(channel.title)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Color.KinoPub.text)
        .lineLimit(1)
    }
  }
}

/// A row in the wide-screen channel list.
struct ChannelRow: View {
  let channel: TVChannel
  let isSelected: Bool

  var body: some View {
    HStack(spacing: 12) {
      ChannelArtwork(logo: channel.logo)
        .frame(width: 72, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
      Text(channel.title)
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(Color.KinoPub.text)
        .lineLimit(2)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(isSelected ? Color.KinoPub.selectionBackground : Color.clear)
    )
  }
}

/// Shared channel logo artwork on a black plate.
struct ChannelArtwork: View {
  let logo: String?

  var body: some View {
    ZStack {
      Color.black
      CachedAsyncImage(url: URL(string: logo ?? "")) { image in
        image
          .resizable()
          .renderingMode(.original)
          .aspectRatio(contentMode: .fit)
          .padding(8)
      } placeholder: {
        Image(systemName: "play.tv.fill")
          .font(.system(size: 22))
          .foregroundStyle(Color.KinoPub.subtitle)
      }
    }
  }
}

struct SportView_Previews: PreviewProvider {
  static var previews: some View {
    SportView(model: SportModel(itemsService: VideoContentServiceMock(),
                                authState: AuthState(authService: AuthorizationServiceMock(), accessTokenService: AccessTokenServiceMock()),
                                errorHandler: ErrorHandler()))
  }
}
