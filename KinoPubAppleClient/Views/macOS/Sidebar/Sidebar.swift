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

  @Environment(\.appContext) var appContext
  @EnvironmentObject var authState: AuthState
  @EnvironmentObject var errorHandler: ErrorHandler
  @EnvironmentObject var navigationState: NavigationState

  @State private var showProfile = false

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
        row(.sport)
        row(.collections)
      }

      Section("Other".localized) {
        row(.watching)
        row(.bookmarks)
        row(.history)
        row(.downloads)
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
    Label(item.title.localized, systemImage: item.systemImage)
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
#if os(macOS)
        ToolbarItem(placement: .cancellationAction) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .fontWeight(.bold)
          }
        }
#else
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .fontWeight(.bold)
          }
        }
#endif
      }
  }
}

struct Sidebar_Previews: PreviewProvider {
  struct Preview: View {
    @State private var selection: SidebarItem? = .new
    var body: some View {
      Sidebar(selection: $selection)
        .environmentObject(AuthState(authService: AuthorizationServiceMock(),
                                     accessTokenService: AccessTokenServiceMock()))
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
