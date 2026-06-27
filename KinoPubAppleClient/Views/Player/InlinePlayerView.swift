//
//  InlinePlayerView.swift
//  KinoPubAppleClient
//
//  An embedded (non-modal) 16:9 player with native controls and a fullscreen toggle,
//  used by the wide-screen Sport layout to play a live channel right in the third column.
//

import SwiftUI
import AVKit
import AVFoundation

struct InlinePlayerView: View {
  let url: URL

  var body: some View {
    PlatformInlinePlayer(url: url)
      .aspectRatio(16.0 / 9.0, contentMode: .fit)
      .background(Color.black)
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }
}

#if os(iOS)
struct PlatformInlinePlayer: UIViewControllerRepresentable {
  let url: URL

  func makeCoordinator() -> Coordinator { Coordinator() }

  func makeUIViewController(context: Context) -> AVPlayerViewController {
    try? AVAudioSession.sharedInstance().setCategory(.playback)
    try? AVAudioSession.sharedInstance().setActive(true)

    let controller = AVPlayerViewController()
    controller.player = AVPlayer(url: url)
    controller.videoGravity = .resizeAspect
    // PiP re-enabled: keep playing in a floating window while using the rest of the app. The
    // black-screen-on-dismantle problem is handled by the coordinator, which retains the controller
    // while PiP is active (so nilling the player on dismantle is deferred until PiP actually ends).
    controller.allowsPictureInPicturePlayback = true
    controller.canStartPictureInPictureAutomaticallyFromInline = true
    controller.delegate = context.coordinator
    controller.player?.play()
    return controller
  }

  func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {}

  static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: Coordinator) {
    // While PiP is active, keep the player alive (the coordinator retains the controller and tears it
    // down when PiP stops) so the floating window doesn't go black. Otherwise stop & release now.
    if coordinator.isPiPActive {
      coordinator.retainedController = controller
    } else {
      controller.player?.pause()
      controller.player = nil
    }
  }

  final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
    var isPiPActive = false
    /// Keeps the controller alive after SwiftUI dismantles the view, so PiP can continue.
    var retainedController: AVPlayerViewController?

    func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
      isPiPActive = true
    }

    func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
      isPiPActive = false
      retainedController?.player?.pause()
      retainedController?.player = nil
      retainedController = nil
    }
  }
}
#else
struct PlatformInlinePlayer: NSViewRepresentable {
  let url: URL

  func makeNSView(context: Context) -> AVPlayerView {
    let view = AVPlayerView()
    view.player = AVPlayer(url: url)
    view.controlsStyle = .inline
    view.showsFullScreenToggleButton = true
    view.allowsPictureInPicturePlayback = true
    view.player?.play()
    return view
  }

  func updateNSView(_ view: AVPlayerView, context: Context) {}

  static func dismantleNSView(_ view: AVPlayerView, coordinator: ()) {
    view.player?.pause()
    view.player = nil
  }
}
#endif
