//
//  Sidebar.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 11.08.2023.
//

import Foundation
import SwiftUI
import KinoPubUI
import KinoPubBackend

struct Sidebar: View {

  @Binding var selection: SidebarItem?

  var body: some View {
    List(selection: $selection) {
      Section {
        row(.search)
      }

      Section("Library".localized) {
        row(.new)
        ForEach(SidebarItem.libraryCategories, id: \.self) { type in
          row(.category(type))
        }
      }

      Section("Other".localized) {
        row(.watching)
        row(.bookmarks)
        row(.history)
        row(.downloads)
        row(.profile)
      }
    }
    .scrollContentBackground(.hidden)
    .background(Color.KinoPub.background)
    .navigationTitle("kinopub")
#if os(macOS)
    .navigationSplitViewColumnWidth(min: 220, ideal: 240)
#endif
  }

  @ViewBuilder
  func row(_ item: SidebarItem) -> some View {
    NavigationLink(value: item) {
      Label(item.title.localized, systemImage: item.systemImage)
        .foregroundStyle(Color.white)
    }
    .listRowBackground(selection == item ? Color.KinoPub.accent : Color.clear)
    .tint(Color.clear)
  }
}

struct Sidebar_Previews: PreviewProvider {
  struct Preview: View {
    @State private var selection: SidebarItem? = .new
    var body: some View {
      Sidebar(selection: $selection)
    }
  }

  static var previews: some View {
    NavigationSplitView {
      Preview()
    } detail: {
      Text("Detail!")
    }
  }
}
