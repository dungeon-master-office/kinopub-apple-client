//
//  ImageCache.swift
//
//
//  A lightweight two-tier (memory + disk) image cache with a time-based expiry.
//  Disk entries older than `ttl` are treated as stale and purged; the whole cache
//  can be cleared on demand (e.g. from Settings).
//

import Foundation
import CryptoKit

#if canImport(UIKit)
import UIKit
public typealias KinoPlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
public typealias KinoPlatformImage = NSImage
#endif

public final class ImageCache {

  /// Shared instance. Default time-to-live is ~6 months.
  public static let shared = ImageCache(ttl: 60 * 60 * 24 * 182)

  private let memory = NSCache<NSString, KinoPlatformImage>()
  private let fileManager = FileManager.default
  private let directory: URL
  private let ttl: TimeInterval

  public init(ttl: TimeInterval) {
    self.ttl = ttl
    let caches = (try? fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
      ?? URL(fileURLWithPath: NSTemporaryDirectory())
    directory = caches.appendingPathComponent("KinoPubImageCache", isDirectory: true)
    try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    memory.countLimit = 300
  }

  // MARK: - Keys

  private func key(for url: URL) -> String {
    let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
  }

  private func fileURL(for url: URL) -> URL {
    directory.appendingPathComponent(key(for: url))
  }

  // MARK: - Reads

  /// Synchronous memory-only lookup (cheap; safe to call during view updates).
  public func cachedImage(for url: URL) -> KinoPlatformImage? {
    memory.object(forKey: key(for: url) as NSString)
  }

  /// Returns a fresh image from memory, disk (if not expired), or the network.
  public func image(for url: URL) async -> KinoPlatformImage? {
    let nsKey = key(for: url) as NSString
    if let image = memory.object(forKey: nsKey) {
      return image
    }

    let file = fileURL(for: url)
    if let attrs = try? fileManager.attributesOfItem(atPath: file.path),
       let modified = attrs[.modificationDate] as? Date {
      if Date().timeIntervalSince(modified) < ttl,
         let data = try? Data(contentsOf: file),
         let image = KinoPlatformImage(data: data) {
        memory.setObject(image, forKey: nsKey)
        return image
      } else {
        try? fileManager.removeItem(at: file) // expired
      }
    }

    // Reject non-2xx responses (e.g. the actor portrait CDN returns 403 for a missing photo) so the
    // caller falls back to its placeholder (initials) instead of a default/error body.
    guard let (data, response) = try? await URLSession.shared.data(from: url),
          (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true,
          let image = KinoPlatformImage(data: data) else {
      return nil
    }
    memory.setObject(image, forKey: nsKey)
    try? data.write(to: file, options: .atomic) // modification date = now
    return image
  }

  // MARK: - Maintenance

  /// Removes every cached entry (memory + disk).
  public func clear() {
    memory.removeAllObjects()
    if let items = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
      for item in items { try? fileManager.removeItem(at: item) }
    }
  }

  /// Drops disk entries older than `ttl`. Safe to call on launch.
  public func purgeExpired() {
    DispatchQueue.global(qos: .utility).async { [self] in
      guard let items = try? fileManager.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: [.contentModificationDateKey]
      ) else { return }
      let now = Date()
      for item in items {
        if let date = try? item.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
           now.timeIntervalSince(date) >= ttl {
          try? fileManager.removeItem(at: item)
        }
      }
    }
  }

  /// Total size of the on-disk cache in bytes.
  public func diskUsageBytes() -> Int {
    guard let items = try? fileManager.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: [.fileSizeKey]
    ) else { return 0 }
    return items.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
  }

  /// Human-readable on-disk cache size (e.g. "12.4 MB").
  public func formattedDiskUsage() -> String {
    ByteCountFormatter.string(fromByteCount: Int64(diskUsageBytes()), countStyle: .file)
  }
}
