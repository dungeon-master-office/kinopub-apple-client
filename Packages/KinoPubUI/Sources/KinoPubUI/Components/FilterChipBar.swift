//
//  FilterChipBar.swift
//
//
//  A single, reusable horizontal "chip" filter bar so every screen with section-style
//  filtering (History, Watching, Collections, …) shares the same native look.
//

import SwiftUI

public struct FilterChipItem: Identifiable, Hashable {
  public let id: String
  public let title: String

  public init(id: String, title: String) {
    self.id = id
    self.title = title
  }
}

public struct FilterChipBar: View {

  private let items: [FilterChipItem]
  @Binding private var selection: String

  public init(items: [FilterChipItem], selection: Binding<String>) {
    self.items = items
    self._selection = selection
  }

  public var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(items) { item in
          chip(item)
        }
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 10)
    }
  }

  private func chip(_ item: FilterChipItem) -> some View {
    let isSelected = item.id == selection
    return Button {
      selection = item.id
    } label: {
      Text(item.title)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(isSelected ? Color.white : Color.KinoPub.text)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background {
          Capsule(style: .continuous)
            .fill(isSelected ? Color.KinoPub.accent : Color.KinoPub.selectionBackground)
        }
    }
    .buttonStyle(.plain)
    .animation(.easeInOut(duration: 0.15), value: isSelected)
  }
}
