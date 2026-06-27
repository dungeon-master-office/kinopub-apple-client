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
  @StateObject private var model: SportModel
  // Shares the app-wide Route type so the detail column never mismatches path types on switch.
  @State private var path: [Route] = []
  /// When pushed inside the custom "Ещё" stack, render bare (the More tab provides the stack).
  @Environment(\.sectionEmbedded) private var sectionEmbedded

  /// Ticking clock: the on-air programme and progress bars refresh against this (~every 30s).
  @State private var now = Date()
  private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

  /// Caps the top player on wide screens so it never stretches full-width ugly.
  private let playerMaxWidth: CGFloat = 900
  /// Comfortable reading width for the channel list on very wide screens.
  private let listMaxWidth: CGFloat = 900

  init(model: @autoclosure @escaping () -> SportModel) {
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
    content
      .kinoScreen("Sport".localized)
      .refreshable { await model.refresh() }
      .onReceive(ticker) { now = $0 }
      .handleError(state: $errorHandler.state)
  }

  @ViewBuilder
  private var content: some View {
    if model.isLoading {
      loadingPlaceholder
    } else if model.channels.isEmpty {
      emptyState
    } else {
      guideLayout
    }
  }

  // MARK: - Unified layout: player pinned on top, channel + programme list below

  /// One arrangement everywhere: the 16:9 player stays pinned at the top (outside the scroll),
  /// and the channels scroll underneath. Tapping a row switches the top player.
  private var guideLayout: some View {
    VStack(spacing: 0) {
      playerHeader
      Divider()
      guideStatusBar
      channelList
    }
  }

  /// Thin status strip under the player: a spinner + "loading guide" while the EPG downloads,
  /// then a "guide updated at HH:mm" confirmation (also reassures after pull-to-refresh).
  @ViewBuilder
  private var guideStatusBar: some View {
    Group {
      if model.isLoadingGuide {
        HStack(spacing: 8) {
          ProgressView().controlSize(.small)
          Text("Loading guide".localized)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.KinoPub.subtitle)
          Spacer(minLength: 0)
        }
      } else if let updated = model.guideUpdatedAt {
        HStack(spacing: 6) {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 11))
            .foregroundStyle(Color.KinoPub.accent)
          Text("\("Guide updated".localized) \(EPGTimeFormat.dateTime.string(from: updated))")
            .font(.system(size: 12))
            .foregroundStyle(Color.KinoPub.subtitle)
          Spacer(minLength: 0)
        }
      }
    }
    .frame(maxWidth: listMaxWidth)
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 16)
    .padding(.vertical, model.isLoadingGuide || model.guideUpdatedAt != nil ? 8 : 0)
  }

  /// Always-on-top player. Centered and width-capped on wide screens; black 16:9 always.
  @ViewBuilder
  private var playerHeader: some View {
    Group {
      if let channel = model.selectedChannel, let url = URL(string: channel.stream) {
        // InlinePlayerView already applies its own black 16:9 frame and rounded clip.
        InlinePlayerView(url: url)
          .id(channel.id) // recreate the AVPlayer when the channel changes
      } else {
        // No selection yet (or an empty stream): a quiet placeholder in the player area.
        ZStack {
          Color.black
          Image(systemName: "play.tv")
            .font(.system(size: 44))
            .foregroundStyle(Color.KinoPub.subtitle)
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
      }
    }
    .frame(maxWidth: playerMaxWidth)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .frame(maxWidth: .infinity) // center the capped player on wide screens
    .padding(16)
    .background(Color.KinoPub.background)
  }

  /// The scrolling channel list. Each row merges the channel with its now/next programme info.
  private var channelList: some View {
    ScrollView {
      LazyVStack(spacing: 6) {
        ForEach(model.channels) { channel in
          ChannelEPGRow(channel: channel,
                        current: model.currentProgram(for: channel, at: now),
                        next: model.nextProgram(for: channel, at: now),
                        now: now,
                        isSelected: channel.id == model.selectedChannel?.id,
                        isLoadingGuide: model.isLoadingGuide)
            .onTapGesture { model.selectedChannel = channel }
        }
      }
      .frame(maxWidth: listMaxWidth)
      .frame(maxWidth: .infinity) // center the list on very wide screens
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
    }
    .background(Color.KinoPub.background)
  }

  // MARK: - Loading placeholder (no fullscreen spinner)

  /// Mirror the real layout while channels load: a locked black 16:9 player on top and a few
  /// redacted channel rows below — never a fullscreen loader.
  private var loadingPlaceholder: some View {
    VStack(spacing: 0) {
      lockedPlayerPlaceholder
      Divider()
      ScrollView {
        LazyVStack(spacing: 6) {
          ForEach(0..<10, id: \.self) { _ in skeletonRow }
        }
        .frame(maxWidth: listMaxWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
      }
      .background(Color.KinoPub.background)
      .disabled(true)
    }
  }

  /// A redacted stand-in for a `ChannelEPGRow` (logo plate + a few text lines + progress bar).
  private var skeletonRow: some View {
    HStack(spacing: 12) {
      RoundedRectangle(cornerRadius: 6, style: .continuous)
        .fill(Color.KinoPub.skeleton)
        .frame(width: 76, height: 44)
      VStack(alignment: .leading, spacing: 6) {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
          .fill(Color.KinoPub.skeleton)
          .frame(width: 120, height: 12)
        RoundedRectangle(cornerRadius: 4, style: .continuous)
          .fill(Color.KinoPub.skeleton)
          .frame(width: 180, height: 10)
        RoundedRectangle(cornerRadius: 2, style: .continuous)
          .fill(Color.KinoPub.skeleton)
          .frame(height: 3)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .redacted(reason: .placeholder)
  }

  private var lockedPlayerPlaceholder: some View {
    Rectangle()
      .fill(Color.black)
      .aspectRatio(16.0 / 9.0, contentMode: .fit)
      .frame(maxWidth: playerMaxWidth)
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .frame(maxWidth: .infinity)
      .padding(16)
      .background(Color.KinoPub.background)
  }

  // MARK: - States

  private var emptyState: some View {
    EmptyStateView(systemImage: "sportscourt", title: "No live broadcasts right now".localized)
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
                                epgService: EPGServiceMock(),
                                authState: AuthState(authService: AuthorizationServiceMock(), accessTokenService: AccessTokenServiceMock(), deviceService: DeviceServiceMock()),
                                errorHandler: ErrorHandler()))
  }
}
