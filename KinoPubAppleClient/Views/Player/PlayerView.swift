//
//  PlayerView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 3.08.2023.
//

import Foundation
import SwiftUI
import AVKit
#if os(iOS)
import UIKit
#endif

struct PlayerView: View {

  @StateObject private var playerManager: PlayerManager
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var navigationState: NavigationState

  init(manager: @autoclosure @escaping () -> PlayerManager) {
    _playerManager = StateObject(wrappedValue: manager())
  }

  var body: some View {
#if os(iOS)
    // Fully native AVPlayerViewController (its own controls, Done button, gestures, PiP).
    NativePlayerView(player: playerManager.player,
                     resumeTime: playerManager.continueTime,
                     onResume: { playerManager.seekToContinueWatching() },
                     onStartOver: { playerManager.cancelContinueWatching() },
                     onFinished: { dismiss() })
      .ignoresSafeArea(.all)
      .navigationBarHidden(true)
      .toolbar(.hidden, for: .tabBar)
      .onAppear {
        UIApplication.shared.isIdleTimerDisabled = true
        configureAudioSession()
        // Don't force-rotate into landscape on open — let the current orientation stand (the native
        // player still rotates freely when the user physically turns the device).
        toggleSidebar()
        Task { await playerManager.fetchWatchMark() }
      }
      .onDisappear {
        UIApplication.shared.isIdleTimerDisabled = false
        AppDelegate.orientationLock = .all
      }
#elseif os(macOS)
    VideoPlayer(player: playerManager.player)
      .ignoresSafeArea(.all)
      .toolbar(.hidden, for: .windowToolbar)
      .onAppear {
        toggleSidebar()
        playerManager.player.play()
        Task {
          await playerManager.fetchWatchMark()
          playerManager.seekToContinueWatching() // auto-resume
        }
      }
#endif
  }

#if os(iOS)
  private func configureAudioSession() {
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .moviePlayback)
    try? session.setActive(true)
  }
#endif

  private func toggleSidebar() {
    navigationState.columnVisibility = .detailOnly
  }
}

#if os(iOS)
/// Hosts a natively-presented `AVPlayerViewController` (so we get its built-in Done button,
/// PiP and gestures with no custom overlay), and a native "Continue Watching" alert.
private struct NativePlayerView: UIViewControllerRepresentable {
  let player: AVPlayer
  let resumeTime: TimeInterval?
  let onResume: () -> Void
  let onStartOver: () -> Void
  let onFinished: () -> Void

  func makeUIViewController(context: Context) -> PlayerHostController {
    let host = PlayerHostController()
    host.player = player
    host.resumeTime = resumeTime
    host.onResume = onResume
    host.onStartOver = onStartOver
    host.onFinished = onFinished
    return host
  }

  func updateUIViewController(_ host: PlayerHostController, context: Context) {
    // The resume point may arrive asynchronously (server fetch); keep the host in sync and let it
    // show the alert once it's available.
    host.resumeTime = resumeTime
    host.onResume = onResume
    host.onStartOver = onStartOver
    host.onFinished = onFinished
    host.presentResumeAlertIfNeeded()
  }
}

/// A black host controller that presents the player in `viewDidAppear` (guaranteed to be in a window,
/// so presentation always succeeds — pushing from the embedded Downloads / trailer routes previously
/// raced the window check and left a black, non-dismissable screen). Reports the native Done so the
/// route pops.
final class PlayerHostController: UIViewController {
  var player: AVPlayer?
  var resumeTime: TimeInterval?
  var onResume: (() -> Void)?
  var onStartOver: (() -> Void)?
  var onFinished: (() -> Void)?

  private var didPresent = false
  private var didAskResume = false
  private weak var playerController: AVPlayerViewController?

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if !didPresent {
      presentPlayer()
    } else if presentedViewController == nil {
      // Returned from the native player (Done) → pop the route.
      onFinished?()
    }
  }

  private func presentPlayer() {
    guard let player else { return }
    didPresent = true

    let controller = AVPlayerViewController()
    controller.player = player
    controller.allowsPictureInPicturePlayback = true
    controller.canStartPictureInPictureAutomaticallyFromInline = true
    controller.modalPresentationStyle = .fullScreen
    playerController = controller

    present(controller, animated: true) { [weak self] in
      player.play()
      self?.presentResumeAlertIfNeeded()
    }
  }

  func presentResumeAlertIfNeeded() {
    guard !didAskResume,
          let resume = resumeTime, resume > 0,
          let controller = playerController,
          controller.viewIfLoaded?.window != nil,
          controller.presentedViewController == nil else { return }
    didAskResume = true

    let alert = UIAlertController(title: "Continue Watching".localized,
                                  message: Self.timeString(resume),
                                  preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "Resume".localized, style: .default) { [weak self] _ in
      self?.onResume?()
    })
    alert.addAction(UIAlertAction(title: "Start from Beginning".localized, style: .default) { [weak self] _ in
      self?.onStartOver?()
    })
    controller.present(alert, animated: true)
  }

  private static func timeString(_ time: TimeInterval) -> String {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute, .second]
    formatter.unitsStyle = .positional
    formatter.zeroFormattingBehavior = .pad
    return formatter.string(from: time) ?? ""
  }
}
#endif
