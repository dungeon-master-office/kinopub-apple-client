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
      .playbackErrorAlert($playerManager.playbackError, onDismiss: { dismiss() })
#elseif os(macOS)
    // Native macOS player (AVKit): floating controls, scrubber, volume, the system fullscreen toggle
    // and PiP — the standard QuickTime-style experience. No custom close button; exit with Esc, or the
    // standard back button in the window toolbar once out of fullscreen.
    MacNativePlayer(player: playerManager.player)
      .ignoresSafeArea(.all)
      .onExitCommand { closePlayer() }
      .onAppear {
      toggleSidebar()
      playerManager.player.play()
      Task {
        await playerManager.fetchWatchMark()
        playerManager.seekToContinueWatching() // auto-resume
      }
    }
    .playbackErrorAlert($playerManager.playbackError, onDismiss: { dismiss() })
#endif
  }

#if os(macOS)
  private func closePlayer() {
    playerManager.player.pause()
    dismiss()
  }
#endif

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

#if os(macOS)
/// The native macOS video view (AVKit `AVPlayerView`) — floating controls, scrubber, volume, the
/// system fullscreen toggle and PiP, matching how video plays elsewhere on the system.
private struct MacNativePlayer: NSViewRepresentable {
  let player: AVPlayer

  func makeCoordinator() -> Coordinator { Coordinator() }

  func makeNSView(context: Context) -> AVPlayerView {
    let view = AVPlayerView()
    view.player = player
    view.controlsStyle = .floating
    view.showsFullScreenToggleButton = true
    view.allowsPictureInPicturePlayback = true
    view.videoGravity = .resizeAspect
    // Open straight into fullscreen, like a system video player. Toggle the window once it's attached;
    // remember we did it so closing the player leaves fullscreen too.
    DispatchQueue.main.async { [weak view] in
      guard let window = view?.window, !window.styleMask.contains(.fullScreen) else { return }
      context.coordinator.enteredFullScreen = true
      window.toggleFullScreen(nil)
    }
    return view
  }

  func updateNSView(_ view: AVPlayerView, context: Context) {
    if view.player !== player { view.player = player }
  }

  static func dismantleNSView(_ view: AVPlayerView, coordinator: Coordinator) {
    if coordinator.enteredFullScreen, let window = view.window, window.styleMask.contains(.fullScreen) {
      window.toggleFullScreen(nil)
    }
    view.player?.pause()
    view.player = nil
  }

  final class Coordinator {
    var enteredFullScreen = false
  }
}
#endif

private extension View {
  /// Presents the player's failure diagnosis (and pops the player on dismiss) so an unplayable
  /// stream is visible on-device rather than just a silent crossed-out play.
  func playbackErrorAlert(_ error: Binding<String?>, onDismiss: @escaping () -> Void) -> some View {
    alert("Playback failed".localized,
          isPresented: Binding(get: { error.wrappedValue != nil },
                               set: { if !$0 { error.wrappedValue = nil } })) {
      Button("OK", role: .cancel) { onDismiss() }
    } message: {
      Text(error.wrappedValue ?? "")
    }
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
    // A long-lived coordinator keeps the player alive during PiP (so leaving this screen — which pops
    // the route and tears down this host — doesn't kill the floating window) and re-presents it when
    // the user taps "restore". Native PiP, no custom UI.
    controller.delegate = PlayerPiPCoordinator.shared
    playerController = controller

    present(controller, animated: true) { [weak self] in
      player.play()
      self?.presentResumeAlertIfNeeded()
    }
  }

  func presentResumeAlertIfNeeded() {
    // Always continue from where the user left off — no "Resume / Start over" prompt.
    guard !didAskResume,
          let resume = resumeTime, resume > 0,
          let controller = playerController,
          controller.viewIfLoaded?.window != nil else { return }
    didAskResume = true
    onResume?()
  }

  private static func timeString(_ time: TimeInterval) -> String {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute, .second]
    formatter.unitsStyle = .positional
    formatter.zeroFormattingBehavior = .pad
    return formatter.string(from: time) ?? ""
  }
}

/// App-lifetime delegate so native Picture-in-Picture survives the player route being popped.
///
/// When PiP starts, the presented `AVPlayerViewController` auto-dismisses (so the app is usable) and
/// this host's route pops — which would normally deallocate the player and black out the PiP window.
/// Holding a strong reference here keeps the player (and its `AVPlayer`) alive for the lifetime of the
/// PiP session, and re-presents it from the top-most controller when the user taps "restore".
final class PlayerPiPCoordinator: NSObject, AVPlayerViewControllerDelegate {
  static let shared = PlayerPiPCoordinator()

  private var retained: AVPlayerViewController?

  func playerViewControllerWillStartPictureInPicture(_ controller: AVPlayerViewController) {
    retained = controller
  }

  func playerViewControllerDidStopPictureInPicture(_ controller: AVPlayerViewController) {
    if retained === controller { retained = nil }
  }

  func playerViewController(_ controller: AVPlayerViewController,
                            restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
    guard controller.presentingViewController == nil, let top = Self.topViewController() else {
      completionHandler(true)
      return
    }
    top.present(controller, animated: true) { completionHandler(true) }
  }

  private static func topViewController() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
    var top = scene?.keyWindow?.rootViewController
      ?? scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }
}
#endif
