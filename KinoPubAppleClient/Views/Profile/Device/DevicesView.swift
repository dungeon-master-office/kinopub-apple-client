//
//  DevicesView.swift
//  KinoPubAppleClient
//
//  Lists every device on the account (GET /v1/device) and lets the user remove other devices
//  (POST /v1/device/<id>/remove). The current device is marked and not removable here (use Logout).
//

import SwiftUI
import KinoPubBackend

@MainActor
final class DevicesListModel: ObservableObject {
  @Published var devices: [ManagedDevice] = []
  @Published var currentDeviceId: Int?
  @Published var isLoading = true

  private let deviceService: DeviceService
  private let errorHandler: ErrorHandler

  init(deviceService: DeviceService, errorHandler: ErrorHandler) {
    self.deviceService = deviceService
    self.errorHandler = errorHandler
  }

  func load() async {
    isLoading = true
    currentDeviceId = try? await deviceService.fetchCurrentDevice().id
    do {
      devices = try await deviceService.listDevices()
    } catch {
      errorHandler.setError(error)
    }
    isLoading = false
  }

  func remove(_ device: ManagedDevice) async {
    do {
      try await deviceService.removeDevice(id: device.id)
      devices.removeAll { $0.id == device.id }
    } catch {
      errorHandler.setError(error)
    }
  }
}

struct DevicesView: View {
  @StateObject private var model: DevicesListModel
  @State private var pendingRemove: ManagedDevice?

  init(model: @autoclosure @escaping () -> DevicesListModel) {
    _model = StateObject(wrappedValue: model())
  }

  /// Native apps/devices (everything the API doesn't flag as a browser session).
  private var devices: [ManagedDevice] { model.devices.filter { !($0.isBrowser ?? false) } }
  /// Web/browser sessions reported alongside devices by the API.
  private var sessions: [ManagedDevice] { model.devices.filter { $0.isBrowser ?? false } }

  var body: some View {
    ZStack {
      Color.KinoPub.background.edgesIgnoringSafeArea(.all)
      if model.isLoading {
        ProgressView()
      } else {
        Form {
          // Real devices and browser sessions are separated so the list isn't a confusing mix.
          if !devices.isEmpty {
            Section(header: Text("Devices".localized),
                    footer: Text("Remove devices you no longer use. The current device can't be removed here — use Logout.".localized)) {
              ForEach(devices) { device in
                row(device)
              }
            }
          }
          if !sessions.isEmpty {
            Section(header: Text("Browser sessions".localized)) {
              ForEach(sessions) { device in
                row(device)
              }
            }
          }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.KinoPub.background)
      }
    }
    .navigationTitle("Devices".localized)
    .task { await model.load() }
    .alert("Remove device?".localized, isPresented: Binding(get: { pendingRemove != nil },
                                                            set: { if !$0 { pendingRemove = nil } })) {
      Button("Cancel".localized, role: .cancel) {}
      Button("Remove".localized, role: .destructive) {
        if let device = pendingRemove { Task { await model.remove(device) } }
      }
    } message: {
      Text(pendingRemove.map { displayName($0) } ?? "")
    }
  }

  @ViewBuilder
  private func row(_ device: ManagedDevice) -> some View {
    let isCurrent = device.id == model.currentDeviceId
    HStack(spacing: 12) {
      Image(systemName: (device.isBrowser ?? false) ? "globe" : "ipad.and.iphone")
        .foregroundStyle(Color.KinoPub.subtitle)
      VStack(alignment: .leading, spacing: 2) {
        Text(displayName(device))
          .foregroundStyle(Color.KinoPub.text)
        if let software = device.software, !software.trimmingCharacters(in: .whitespaces).isEmpty {
          Text(software).font(.caption).foregroundStyle(Color.KinoPub.subtitle)
        }
        if let last = device.lastSeen {
          Text(String(format: "Last seen %@".localized, Self.dateText(last)))
            .font(.caption2).foregroundStyle(Color.KinoPub.subtitle)
        }
      }
      Spacer()
      if isCurrent {
        Text("This device".localized).font(.caption).foregroundStyle(Color.KinoPub.accent)
      } else {
        Button(role: .destructive) {
          pendingRemove = device
        } label: {
          Image(systemName: "trash")
        }
        .buttonStyle(.borderless)
      }
    }
  }

  private func displayName(_ device: ManagedDevice) -> String {
    let title = device.title?.trimmingCharacters(in: .whitespaces) ?? ""
    if !title.isEmpty { return title }
    let hardware = device.hardware?.trimmingCharacters(in: .whitespaces) ?? ""
    return hardware.isEmpty ? "Unknown device".localized : hardware
  }

  private static func dateText(_ ts: TimeInterval) -> String {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .short
    return f.string(from: Date(timeIntervalSince1970: ts))
  }
}
