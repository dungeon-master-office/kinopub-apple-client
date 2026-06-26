//
//  ToastMessage.swift
//  KinoPubUI
//
//  Typed payload for the bottom toast so confirmations, errors and warnings read differently
//  (colour + icon) instead of every message being red.
//

import SwiftUI

/// Visual kind of a toast. Drives the background colour and the leading SF Symbol.
public enum ToastStyle: Hashable, Sendable {
  case success
  case error
  case info
  case warning

  public var tint: Color {
    switch self {
    case .success: return Color.KinoPub.accent      // brand green
    case .error:   return Color.KinoPub.accentRed
    case .info:    return Color.KinoPub.accentBlue
    case .warning: return Color.orange
    }
  }

  public var icon: String {
    switch self {
    case .success: return "checkmark.circle.fill"
    case .error:   return "exclamationmark.triangle.fill"
    case .info:    return "info.circle.fill"
    case .warning: return "exclamationmark.circle.fill"
    }
  }
}

/// A toast's text plus its style. Use the `success`/`error`/`info`/`warning` factories at call sites.
public struct ToastMessage: Hashable, Sendable {
  public var text: String
  public var style: ToastStyle

  public init(_ text: String, style: ToastStyle = .info) {
    self.text = text
    self.style = style
  }

  public static func success(_ text: String) -> ToastMessage { .init(text, style: .success) }
  public static func error(_ text: String) -> ToastMessage { .init(text, style: .error) }
  public static func info(_ text: String) -> ToastMessage { .init(text, style: .info) }
  public static func warning(_ text: String) -> ToastMessage { .init(text, style: .warning) }
}
