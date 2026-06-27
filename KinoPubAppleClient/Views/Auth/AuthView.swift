//
//  AuthView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 24.07.2023.
//
import SwiftUI
import KinoPubUI
import PopupView
#if canImport(AppKit)
import AppKit
#endif

struct AuthView: View {

  @StateObject var model: AuthModel
  @EnvironmentObject var errorHandler: ErrorHandler
  @Environment(\.dismiss) var dismiss
  @State private var copied = false

  init(model: @autoclosure @escaping () -> AuthModel) {
    _model = StateObject(wrappedValue: model())
  }

  var body: some View {
    ZStack(alignment: .topTrailing) {
      Color.KinoPub.background.ignoresSafeArea()
      ScrollView {
        VStack(spacing: 28) {
          logo
          titleView
          codeCard
          activateButton
          urlHint
        }
        .frame(maxWidth: 460)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 40)
      }

      // There's nothing usable behind the activation gate, so the close button (and Esc) quits the
      // app rather than dropping into an unauthorized, empty session.
      Button { quitApp() } label: {
        Image(systemName: "xmark")
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(Color.KinoPub.subtitle)
          .frame(width: 44, height: 44)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .padding(8)
      .keyboardShortcut(.cancelAction)
    }
    .interactiveDismissDisabled(true)
    .task {
      model.fetchDeviceCode()
    }
    .onReceive(model.$close, perform: { shouldClose in
      if shouldClose {
        dismiss()
      }
    })
    .handleError(state: $errorHandler.state)
  }

  private func quitApp() {
    #if os(macOS)
    NSApplication.shared.terminate(nil)
    #else
    exit(0)
    #endif
  }

  private var logo: some View {
    Image(systemName: "play.tv.fill")
      .font(.system(size: 40, weight: .semibold))
      .foregroundStyle(Color.KinoPub.accent)
      .frame(width: 88, height: 88)
      .background(Circle().fill(Color.KinoPub.accent.opacity(0.15)))
  }

  var titleView: some View {
    VStack(spacing: 10) {
      Text("Auth_CodeActivationTitle")
        .font(.system(size: 24, weight: .bold))
        .foregroundStyle(Color.KinoPub.text)
        .multilineTextAlignment(.center)
      Text("Auth_CodeActivationText")
        .font(.system(size: 15))
        .foregroundStyle(Color.KinoPub.subtitle)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  /// The code in a tappable card — tapping copies it (with a brief checkmark confirmation).
  private var codeCard: some View {
    VStack(spacing: 12) {
      Text("Auth_DeviceCode")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Color.KinoPub.subtitle)
        .textCase(.uppercase)
      if model.deviceCode.isEmpty {
        ProgressView().frame(height: 48)
      } else {
        Button {
          model.copyCode()
          withAnimation { copied = true }
          DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { withAnimation { copied = false } }
        } label: {
          HStack(spacing: 12) {
            Text(model.deviceCode)
              .font(.system(size: 40, weight: .bold, design: .monospaced))
              .kerning(4)
              .foregroundStyle(Color.KinoPub.text)
            Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
              .font(.system(size: 20))
              .foregroundStyle(copied ? Color.green : Color.KinoPub.accent)
          }
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.vertical, 22)
    .padding(.horizontal, 24)
    .frame(maxWidth: .infinity)
    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.06)))
    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.06)))
  }

  var activateButton: some View {
    Button(action: { model.openActivationURL() }) {
      Text("Auth_Activate")
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.KinoPub.accent))
    }
    .buttonStyle(.plain)
    .disabled(model.deviceCode.isEmpty)
    .opacity(model.deviceCode.isEmpty ? 0.5 : 1)
  }

  @ViewBuilder
  private var urlHint: some View {
    if !model.activationDisplayURL.isEmpty {
      HStack(spacing: 6) {
        Image(systemName: "globe").font(.system(size: 13))
        Text(model.activationDisplayURL).font(.system(size: 14, weight: .medium))
      }
      .foregroundStyle(Color.KinoPub.subtitle)
    }
  }
}

// struct AuthView_Previews: PreviewProvider {
//  static var previews: some View {
//    AuthView()
//  }
// }
