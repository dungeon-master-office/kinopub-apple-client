//
//  SettingsView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 22.07.2023.
//
import SwiftUI
import KinoPubBackend
import KinoPubKit
import KinoPubUI
import SkeletonUI

struct ProfileView: View {

  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var errorHandler: ErrorHandler
  @Environment(\.appContext) var appContext
  @StateObject private var model: ProfileModel
  @AppStorage("selectedLanguage") private var selectedLanguage: String = (Locale.current.language.languageCode?.identifier ?? "en")
  /// Caps streaming quality; read by PlayerManager when building the AVPlayerItem.
  @AppStorage(StreamQuality.userDefaultsKey) private var streamQuality: StreamQuality = .auto

  @State private var showLogoutAlert: Bool = false
  @State private var showStorage: Bool = false
  @Environment(\.sectionEmbedded) private var sectionEmbedded
  @Environment(\.dismiss) private var dismiss

  init(model: @autoclosure @escaping () -> ProfileModel) {
    _model = StateObject(wrappedValue: model())
  }
  
  var body: some View {
    if sectionEmbedded {
      profileContent
    } else {
      NavigationStack { profileContent }
    }
  }

  private var profileContent: some View {
    ZStack {
        Color.KinoPub.background.edgesIgnoringSafeArea(.all)
        VStack(alignment: .leading) {
          Form {
            Section {
              infoRow("User Name", model.userData.username)
                .skeleton(enabled: model.userData.skeleton ?? false)
              infoRow("User Subscription",
                      "\(model.userData.subscription.remainingDays) \("days".localized) · \(model.userData.subscription.endDateFormatted)")
                .skeleton(enabled: model.userData.skeleton ?? false)
              infoRow("Registration Date", "\(model.userData.registrationDateFormatted)")
                .skeleton(enabled: model.userData.skeleton ?? false)
              infoRow("App version", Bundle.main.appVersionLong)
            }
              
            languageSection

            videoQualitySection

            Section {
              Button {
                showStorage = true
              } label: {
                HStack {
                  Text("Storage".localized).foregroundStyle(Color.KinoPub.text)
                  Spacer()
                  Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.KinoPub.subtitle)
                }
                .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
            }

            Section {
              NavigationLink("Sections".localized) {
                SectionsSettingsView()
              }
              NavigationLink("Device settings".localized) {
                DeviceSettingsView(model: DeviceSettingsModel(deviceService: appContext.deviceService,
                                                              errorHandler: errorHandler))
              }
              NavigationLink("Devices".localized) {
                DevicesView(model: DevicesListModel(deviceService: appContext.deviceService,
                                                    errorHandler: errorHandler))
              }
            }

            Section {
              Button(action: {
                showLogoutAlert = true
              }, label: {
                HStack {
                  Text("Logout").foregroundStyle(model.isLoggingOut ? Color.KinoPub.subtitle : Color.red)
                  if model.isLoggingOut {
                    Spacer()
                    ProgressView()
                  }
                }
              })
              .disabled(model.isLoggingOut)
              .skeleton(enabled: model.userData.skeleton ?? false)
              .buttonStyle(.plain)
            }
          }
          .formStyle(.grouped)
          .scrollContentBackground(.hidden)
          .background(Color.KinoPub.background)
        }
      }
      .kinoScreen("Profile".localized)
      .onAppear(perform: {
        model.fetch()
      })
      // Close the profile modal once logout finishes (the activation screen takes over).
      .onChange(of: model.didLogout) { done in
        if done { dismiss() }
      }
      .sheet(isPresented: $showStorage) {
        StorageBreakdownView()
      }
      .alert("Are you sure?", isPresented: $showLogoutAlert) {
        Button("Logout", role: .destructive) { model.logout() }
        Button("Cancel", role: .cancel) { }
      }
      .alert(isPresented: $model.shouldShowExitAlert) {
        Alert(
          title: Text("Restarting the app"),
          message: Text("The app will restart to apply the language change."),
          primaryButton: .default(Text("OK")) {
            exit(0)
          },
          secondaryButton: .cancel()
        )
      }
  }
  /// A leading-aligned label/value row. Avoids `LabeledContent`/`Form`'s macOS right-aligned label
  /// gutter, which clips long labels off the left edge of the Profile sheet.
  private func infoRow(_ label: String, _ value: String) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text(label.localized).foregroundStyle(Color.KinoPub.subtitle)
      Spacer(minLength: 12)
      Text(value)
        .foregroundStyle(Color.KinoPub.text)
        .multilineTextAlignment(.trailing)
    }
  }

  private var videoQualitySection: some View {
    Section(header: Text("Video Quality"),
            footer: Text("Caps streaming quality. Auto lets the player adapt to your connection.".localized)) {
      HStack {
        Text("Maximum Quality".localized).foregroundStyle(Color.KinoPub.text)
        Spacer()
        Picker("", selection: $streamQuality) {
          ForEach(StreamQuality.allCases) { quality in
            Text(quality.title).tag(quality)
          }
        }
        .labelsHidden()
        .pickerStyle(MenuPickerStyle())
      }
    }
  }

  private var languageSection: some View {
    Section(header: Text("Language")) {
      HStack {
        Text("Select Language".localized).foregroundStyle(Color.KinoPub.text)
        Spacer()
        Picker("", selection: $selectedLanguage) {
          ForEach(model.availableLanguages.keys.sorted(), id: \.self) { key in
            Text(model.availableLanguages[key] ?? key).tag(key)
          }
        }
        .labelsHidden()
        .pickerStyle(MenuPickerStyle())
        .onChange(of: selectedLanguage) { newLanguage in
          model.changeLanguage(to: newLanguage)
        }
      }
    }
  }
}

struct ProfileView_Previews: PreviewProvider {
  static var previews: some View {
    ProfileView(model: ProfileModel(userService: UserServiceMock(),
                                    errorHandler: ErrorHandler(),
                                    authState: AuthState(authService: AuthorizationServiceMock(),
                                                         accessTokenService: AccessTokenServiceMock(),
                                                         deviceService: DeviceServiceMock())))
  }
}
