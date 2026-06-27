//
//  SectionsSettingsView.swift
//  KinoPubAppleClient
//
//  Lets the user show/hide library and "other" sections. Films, Serials and Collections are always
//  on. The section order is fixed — this screen only toggles visibility.
//

import SwiftUI

struct SectionsSettingsView: View {
  @ObservedObject private var visibility = SectionVisibilityStore.shared

  var body: some View {
    Form {
      Section(header: Text("Library".localized),
              footer: Text("Films, Serials and Collections can't be hidden.".localized)) {
        ForEach(SectionVisibilityStore.editableLibrary) { row($0) }
      }
      Section(header: Text("Other".localized)) {
        ForEach(SectionVisibilityStore.editableOther) { row($0) }
      }
    }
    .scrollContentBackground(.hidden)
    .background(Color.KinoPub.background)
    .navigationTitle("Sections".localized)
  }

  private func row(_ item: SidebarItem) -> some View {
    Toggle(isOn: Binding(
      get: { visibility.isVisible(item) },
      set: { visibility.setVisible(item, $0) }
    )) {
      Label(item.title.localized, systemImage: item.systemImage)
        .foregroundStyle(Color.KinoPub.text)
    }
    .tint(Color.KinoPub.accent)
    .disabled(!visibility.canHide(item))
  }
}
