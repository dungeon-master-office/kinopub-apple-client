//
//  CastAvatarView.swift
//
//
//  Apple TV-style circular cast/crew avatar with name and role.
//

import SwiftUI

public struct CastAvatarView: View {

  private let imageURL: String?
  private let name: String
  private let role: String?
  private let diameter: CGFloat

  public init(imageURL: String? = nil, name: String, role: String? = nil, diameter: CGFloat = 96) {
    self.imageURL = imageURL
    self.name = name
    self.role = role
    self.diameter = diameter
  }

  private var initials: String {
    let parts = name.split(separator: " ").prefix(2)
    return parts.compactMap { $0.first }.map(String.init).joined().uppercased()
  }

  public var body: some View {
    VStack(spacing: 8) {
      avatar
      Text(name)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(Color.KinoPub.text)
        .lineLimit(1)
      if let role, !role.isEmpty {
        Text(role)
          .font(.system(size: 13))
          .foregroundStyle(Color.KinoPub.subtitle)
          .lineLimit(1)
      }
    }
    .frame(width: diameter + 24)
  }

  @ViewBuilder
  private var avatar: some View {
    if let imageURL, !imageURL.isEmpty {
      CachedAsyncImage(url: URL(string: imageURL)) { image in
        image.resizable().aspectRatio(contentMode: .fill)
      } placeholder: {
        placeholder
      }
      .frame(width: diameter, height: diameter)
      .clipShape(Circle())
    } else {
      placeholder
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
    }
  }

  private var placeholder: some View {
    ZStack {
      Color.KinoPub.skeleton
      Text(initials)
        .font(.system(size: diameter * 0.34, weight: .semibold))
        .foregroundStyle(Color.KinoPub.text)
    }
  }
}
