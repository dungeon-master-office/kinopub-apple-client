//
//  CachedAsyncImage.swift
//
//
//  A drop-in replacement for SwiftUI's AsyncImage that loads through ImageCache
//  (memory + disk with a 6-month expiry) instead of hitting the network every time.
//

import SwiftUI

public struct CachedAsyncImage<Content: View, Placeholder: View>: View {

  private let url: URL?
  private let content: (Image) -> Content
  private let placeholder: () -> Placeholder

  @State private var image: Image?

  public init(url: URL?,
              @ViewBuilder content: @escaping (Image) -> Content,
              @ViewBuilder placeholder: @escaping () -> Placeholder) {
    self.url = url
    self.content = content
    self.placeholder = placeholder
    // Seed synchronously from the memory cache so already-loaded images don't flash a placeholder.
    if let url, let cached = ImageCache.shared.cachedImage(for: url) {
      _image = State(initialValue: Image(platformImage: cached))
    }
  }

  public var body: some View {
    Group {
      if let image {
        content(image)
      } else {
        placeholder()
      }
    }
    .task(id: url) {
      await load()
    }
  }

  @MainActor
  private func load() async {
    guard image == nil else { return }
    guard let url else { return }
    if let loaded = await ImageCache.shared.image(for: url) {
      image = Image(platformImage: loaded)
    }
  }
}

extension Image {
  init(platformImage: KinoPlatformImage) {
#if canImport(UIKit)
    self.init(uiImage: platformImage)
#elseif canImport(AppKit)
    self.init(nsImage: platformImage)
#endif
  }
}
