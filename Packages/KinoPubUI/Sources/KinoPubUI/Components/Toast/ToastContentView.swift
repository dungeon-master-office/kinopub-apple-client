//
//  ToastContentView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 27.07.2023.
//

import Foundation
import SwiftUI

public struct ToastContentView: View {

  public var message: ToastMessage

  public init(message: ToastMessage) {
    self.message = message
  }

  public var body: some View {
    HStack(spacing: 10) {
      Image(systemName: message.style.icon)
        .font(.system(size: 18, weight: .semibold))
      Text(message.text)
        .font(.system(size: 15, weight: .medium))
        .fixedSize(horizontal: false, vertical: true)
    }
    .foregroundColor(.white)
    .padding(.horizontal, 18)
    .padding(.vertical, 14)
    .frame(minHeight: 52)
    .background(message.style.tint)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 4)
  }
}
