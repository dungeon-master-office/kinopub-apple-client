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
import KinoPubKit

struct Sidebar: View {

  @Binding var selection: SidebarItem?

  @Environment(\.appContext) var appContext
  @EnvironmentObject var authState: AuthState
  @EnvironmentObject var errorHandler: ErrorHandler
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var networkMonitor: NetworkMonitor
  @ObservedObject private var visibility = SectionVisibilityStore.shared

  @State private var showProfile = false

  var body: some View {
    // Custom selection binding so picking a section also pops its stack back to root (like a tab bar).
    // Goes through the normal `selection` binding, so List highlighting/behaviour is unaffected.
    List(selection: Binding(
      get: { selection },
      set: { newValue in
        selection = newValue
        if let newValue { navigationState.popToRoot(for: newValue) }
      }
    )) {
      Section("Library".localized) {
        row(.search)
        row(.new)
        ForEach(SidebarItem.libraryCategories, id: \.self) { type in
          if visibility.isVisible(.category(type)) { row(.category(type)) }
        }
        ForEach(CatalogPreset.visible) { preset in
          if visibility.isVisible(.preset(preset)) { row(.preset(preset)) }
        }
        if visibility.isVisible(.sport) { row(.sport) }
        row(.collections)
      }

      Section("Other".localized) {
        ForEach(SectionVisibilityStore.editableOther) { item in
          if visibility.isVisible(item) { row(item) }
        }
      }

      // Profile sits in its own section so it reads as separate from the library/other rows.
      Section {
        Button {
          showProfile = true
        } label: {
          Label("Profile".localized, systemImage: "person.crop.circle")
        }
#if os(macOS)
        .buttonStyle(.borderless)
#else
        .buttonStyle(.plain)
#endif
      }
    }
    .listStyle(.sidebar)
    .scrollContentBackground(.hidden)
    .background(Color.KinoPub.background)
    .navigationTitle("KinoPub")
#if os(macOS)
    .navigationSplitViewColumnWidth(min: 220, ideal: 240)
#endif
    .sheet(isPresented: $showProfile) {
      profileSheet
    }
  }

  @ViewBuilder
  func row(_ item: SidebarItem) -> some View {
    let locked = !networkMonitor.isOnline && !item.isAvailableOffline
    Label {
      HStack {
        Text(item.title.localized)
        if locked {
          Spacer(minLength: 6)
          Image(systemName: "lock.fill").font(.caption2)
        }
      }
    } icon: {
      Image(systemName: item.systemImage)
    }
    .foregroundStyle(locked ? Color.KinoPub.subtitle : Color.KinoPub.text)
    .tag(item)
  }

  private var profileSheet: some View {
    ProfileSheetContent(
      model: ProfileModel(userService: appContext.userService,
                          errorHandler: errorHandler,
                          authState: authState)
    )
    .environmentObject(authState)
    .environmentObject(errorHandler)
    .environmentObject(navigationState)
  }
}

private struct ProfileSheetContent: View {
  @Environment(\.dismiss) private var dismiss
  let model: ProfileModel

  init(model: @autoclosure @escaping () -> ProfileModel) {
    self.model = model()
  }

  var body: some View {
    // ProfileView already provides its own NavigationStack; attach the
    // dismiss control to that bar instead of nesting another stack.
    ProfileView(model: model)
      .toolbar {
        // `.cancellationAction` adapts per platform (no #if): a leading close on iOS/iPad, the
        // standard cancel slot on macOS.
        ToolbarItem(placement: .cancellationAction) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .fontWeight(.bold)
          }
        }
      }
  }
}

struct Sidebar_Previews: PreviewProvider {
  struct Preview: View {
    @State private var selection: SidebarItem? = .new
    var body: some View {
      Sidebar(selection: $selection)
        .environmentObject(AuthState(authService: AuthorizationServiceMock(),
                                     accessTokenService: AccessTokenServiceMock(),
                                     deviceService: DeviceServiceMock()))
        .environmentObject(ErrorHandler())
        .environmentObject(NavigationState())
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
