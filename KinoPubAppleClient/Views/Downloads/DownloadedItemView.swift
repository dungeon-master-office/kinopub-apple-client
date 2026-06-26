//
//  DownloadedItemView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 8.08.2023.
//

import Foundation
import SwiftUI
import KinoPubBackend
import KinoPubUI

public enum DownloadRowState {
  /// In-progress shows %/pause; finished shows a "downloaded" checkmark.
  case auto
  /// Interrupted (force-quit) shows a "re-download" affordance instead of a (false) checkmark.
  case interrupted
}

public struct DownloadedItemView: View {

  private var mediaItem: DownloadMeta
  private var progress: Float?
  private var fileURL: URL?
  private var speed: Double?
  private var remaining: TimeInterval?
  private var state: DownloadRowState
  private var onDownloadStateChange: (Bool) -> Void

  public init(mediaItem: DownloadMeta,
              progress: Float?,
              fileURL: URL? = nil,
              speed: Double? = nil,
              remaining: TimeInterval? = nil,
              state: DownloadRowState = .auto,
              onDownloadStateChange: @escaping (Bool) -> Void) {
    self.mediaItem = mediaItem
    self.progress = progress
    self.fileURL = fileURL
    self.speed = speed
    self.remaining = remaining
    self.state = state
    self.onDownloadStateChange = onDownloadStateChange
  }

  public var body: some View {
    HStack(alignment: .center) {
      image

      VStack(alignment: .leading, spacing: 3) {
        title
        subtitle
        if let detail = fileDetail {
          Text(detail)
            .lineLimit(1)
            .font(.system(size: 11.0, weight: .medium))
            .foregroundStyle(Color.KinoPub.subtitle)
        }
      }.padding(.all, 5)

      if let progress = progress, progress < 1.0 {
        Spacer()
        VStack(alignment: .trailing, spacing: 2) {
          Text("\(Int(progress * 100))%")
            .font(.system(size: 13, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(Color.KinoPub.text)
          if let transfer = transferString {
            Text(transfer)
              .font(.system(size: 10, weight: .medium))
              .monospacedDigit()
              .foregroundStyle(Color.KinoPub.subtitle)
          }
        }
        ProgressButton(progress: progress) { state in
          onDownloadStateChange(state == .pause)
        }
        .buttonStyle(.borderless)
        .padding(.leading, 8)
        .padding(.trailing, 16)
      } else {
        Spacer()
        switch state {
        case .interrupted:
          // Force-quit download: offer a re-download instead of a (misleading) checkmark.
          VStack(spacing: 2) {
            Image(systemName: "arrow.clockwise.circle.fill")
              .font(.system(size: 22))
              .foregroundStyle(.white, Color.KinoPub.accent)
            Text("Re-download".localized)
              .font(.system(size: 10, weight: .medium))
              .foregroundStyle(Color.KinoPub.subtitle)
          }
          .padding(.trailing, 16)
        case .auto:
          // Clear "downloaded" indicator for finished files.
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 20))
            .foregroundStyle(Color.KinoPub.accent)
            .padding(.trailing, 16)
        }
      }
    }
    .padding(.vertical, 8)
  }

  /// "S4E4 · 1080p · 1.4 GB" — episode (series), chosen quality, and on-disk size when known.
  private var fileDetail: String? {
    var parts: [String] = []
    if let episode = mediaItem.episode, !episode.isEmpty {
      parts.append(episode)
    }
    if let quality = mediaItem.quality, !quality.isEmpty {
      parts.append(quality)
    }
    if let size = fileSizeString {
      parts.append(size)
    }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  /// "12.3 MB/s · 0:45 left" — live speed and ETA for an in-progress download.
  private var transferString: String? {
    var parts: [String] = []
    if let speed, speed > 0 {
      parts.append("\(ByteCountFormatter.string(fromByteCount: Int64(speed), countStyle: .file))/s")
    }
    if let remaining, remaining > 0, let eta = Self.etaFormatter.string(from: remaining) {
      parts.append(String(format: "%@ %@", eta, "left".localized))
    }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  private static let etaFormatter: DateComponentsFormatter = {
    let f = DateComponentsFormatter()
    f.allowedUnits = [.hour, .minute, .second]
    f.unitsStyle = .abbreviated
    f.maximumUnitCount = 2
    return f
  }()

  private var fileSizeString: String? {
    guard let fileURL else { return nil }
    let bytes = Self.byteSize(of: fileURL)
    guard bytes > 0 else { return nil }
    return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
  }

  /// On-disk size of the download. An mp4 is a single file; an HLS download is a `.movpkg` *bundle*
  /// (a directory), so `attributesOfItem` returns only the tiny directory entry — we must sum the
  /// contents to report the real size.
  private static func byteSize(of url: URL) -> Int64 {
    let fm = FileManager.default
    var isDirectory: ObjCBool = false
    guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return 0 }
    guard isDirectory.boolValue else {
      let attrs = try? fm.attributesOfItem(atPath: url.path)
      return (attrs?[.size] as? Int64) ?? 0
    }
    let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey]
    guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: keys) else { return 0 }
    var total: Int64 = 0
    for case let child as URL in enumerator {
      let values = try? child.resourceValues(forKeys: Set(keys))
      total += Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? values?.fileSize ?? 0)
    }
    return total
  }
  
  var image: some View {
    CachedAsyncImage(url: URL(string: mediaItem.imageUrl)) { image in
      image.resizable()
        .renderingMode(.original)
        .posterStyle(size: .small, orientation: .vertical)
    } placeholder: {
      Color.KinoPub.skeleton
        .frame(width: PosterStyle.Size.small.width,
               height: PosterStyle.Size.small.height)
    }
    .cornerRadius(8)
  }
  
  var title: some View {
    Text(mediaItem.localizedTitle)
      .lineLimit(1)
      .font(.system(size: 14.0, weight: .medium))
      .foregroundStyle(Color.KinoPub.text)
  }
  
  var subtitle: some View {
    Text(mediaItem.originalTitle)
      .lineLimit(1)
      .font(.system(size: 12.0, weight: .medium))
      .foregroundStyle(Color.KinoPub.subtitle)
  }
  
}

#Preview {
  DownloadedItemView(mediaItem: DownloadMeta.make(from: DownloadableMediaItem(name: "", files: [], mediaItem: MediaItem.mock(), watchingMetadata: WatchingMetadata(id: 0, video: nil, season: nil))), progress: nil) { _ in
    
  }
}

