//
//  EmptyStateView.swift
//
//
//  A single, reusable empty-state placeholder so every screen (Search, History, Bookmarks,
//  Watching, Collections, Sport, Downloads, …) shows the same centered icon + title + message.
//

import SwiftUI

public struct EmptyStateView: View {

  private let systemImage: String
  private let title: String
  private let message: String?

  public init(systemImage: String, title: String, message: String? = nil) {
    self.systemImage = systemImage
    self.title = title
    self.message = message
  }

  public var body: some View {
    VStack(spacing: 10) {
      Image(systemName: systemImage)
        .font(.system(size: 44, weight: .light))
        .foregroundStyle(Color.KinoPub.subtitle)
      Text(title)
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(Color.KinoPub.text)
        .multilineTextAlignment(.center)
      if let message, !message.isEmpty {
        Text(message)
          .font(.system(size: 13))
          .foregroundStyle(Color.KinoPub.subtitle)
          .multilineTextAlignment(.center)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(40)
  }
}
