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
        AppDelegate.orientationLock = .landscape
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

  func makeCoordinator() -> Coordinator { Coordinator(self) }

  func makeUIViewController(context: Context) -> PlayerHostController {
    let host = PlayerHostController()
    host.onDismissed = { context.coordinator.parent.onFinished() }
    context.coordinator.host = host
    return host
  }

  func updateUIViewController(_ host: PlayerHostController, context: Context) {
    context.coordinator.parent = self
    context.coordinator.presentPlayerIfNeeded()
    context.coordinator.presentResumeAlertIfNeeded()
  }

  final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
    var parent: NativePlayerView
    weak var host: PlayerHostController?
    private var playerController: AVPlayerViewController?
    private var didPresentPlayer = false
    private var didAskResume = false

    init(_ parent: NativePlayerView) { self.parent = parent }

    func presentPlayerIfNeeded() {
      guard !didPresentPlayer, let host, host.viewIfLoaded?.window != nil else { return }
      didPresentPlayer = true

      let controller = AVPlayerViewController()
      controller.player = parent.player
      controller.allowsPictureInPicturePlayback = true
      controller.canStartPictureInPictureAutomaticallyFromInline = true
      controller.delegate = self
      controller.modalPresentationStyle = .fullScreen
      playerController = controller
      host.trackPresented(controller)

      host.present(controller, animated: true) { [weak self] in
        self?.parent.player.play()
        self?.presentResumeAlertIfNeeded()
      }
    }

    func presentResumeAlertIfNeeded() {
      guard !didAskResume,
            let resume = parent.resumeTime, resume > 0,
            let controller = playerController,
            controller.viewIfLoaded?.window != nil,
            controller.presentedViewController == nil else { return }
      didAskResume = true

      let alert = UIAlertController(title: "Continue Watching".localized,
                                    message: Self.timeString(resume),
                                    preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "Resume".localized, style: .default) { [weak self] _ in
        self?.parent.onResume()
      })
      alert.addAction(UIAlertAction(title: "Start from Beginning".localized, style: .default) { [weak self] _ in
        self?.parent.onStartOver()
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
}

/// A clear host controller that presents the player and reports when it is dismissed
/// (e.g. the native "Done" button) so SwiftUI can pop the route.
final class PlayerHostController: UIViewController {
  var onDismissed: (() -> Void)?
  private var hasPresented = false

  func trackPresented(_ controller: UIViewController) {
    hasPresented = true
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    // The player modal was presented and is now gone (native Done tapped) -> pop the route.
    if hasPresented && presentedViewController == nil {
      onDismissed?()
    }
  }
}
#endif
