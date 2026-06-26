//
//  DeviceSettingsModel.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 25.06.2026.
//

import Foundation
import KinoPubBackend
import OSLog
import KinoPubLogging
#if canImport(UIKit)
import UIKit
#endif

@MainActor
class DeviceSettingsModel: ObservableObject {

  private var deviceService: DeviceService
  private var errorHandler: ErrorHandler
  private var deviceId: Int?

  @Published var settings: DeviceSettings = DeviceSettings()
  @Published var isLoading: Bool = false
  @Published var isSaving: Bool = false
  @Published var deviceTitle: String = ""
  /// Flips true briefly after a successful save to drive the "Saved" confirmation toast.
  @Published var didSave: Bool = false

  init(deviceService: DeviceService, errorHandler: ErrorHandler) {
    self.deviceService = deviceService
    self.errorHandler = errorHandler
  }

  func load() async {
    isLoading = true
    defer { isLoading = false }
    do {
      let device = try await deviceService.fetchCurrentDevice()
      deviceId = device.id
      deviceTitle = device.title ?? ""
      settings = try await deviceService.fetchSettings(deviceId: device.id)
    } catch {
      Logger.app.debug("load device settings error: \(error)")
      errorHandler.setError(error)
    }
  }

  func save() async {
    guard let deviceId else { return }
    isSaving = true
    defer { isSaving = false }
    do {
      try await deviceService.updateSettings(deviceId: deviceId, settings: settings)
      // Keep what the user chose (optimistic). We intentionally do NOT re-fetch here: the server
      // can be briefly eventually-consistent, and re-reading stale values made the toggles appear
      // to "reset" right after saving.
      confirmSaved()
    } catch {
      Logger.app.debug("save device settings error: \(error)")
      errorHandler.setError(error)
    }
  }

  /// iOS-standard success feedback: a success haptic plus a brief "Saved" confirmation toast.
  private func confirmSaved() {
    #if canImport(UIKit)
    UINotificationFeedbackGenerator().notificationOccurred(.success)
    #endif
    didSave = true
    Task {
      try? await Task.sleep(nanoseconds: 1_800_000_000)
      didSave = false
    }
  }
}
