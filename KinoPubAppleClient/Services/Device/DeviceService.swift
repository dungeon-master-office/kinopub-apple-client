//
//  DeviceService.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 25.06.2026.
//

import Foundation
import KinoPubBackend

protocol DeviceService {
  func fetchCurrentDevice() async throws -> DeviceInfo
  func fetchSettings(deviceId: Int) async throws -> DeviceSettings
  func updateSettings(deviceId: Int, settings: DeviceSettings) async throws
  /// Registers this device's name/specs so it isn't listed as "unknown".
  func registerDeviceName() async
}

protocol DeviceServiceProvider {
  var deviceService: DeviceService { get set }
}

struct DeviceServiceMock: DeviceService {

  func fetchCurrentDevice() async throws -> DeviceInfo {
    DeviceInfo.mock()
  }

  func fetchSettings(deviceId: Int) async throws -> DeviceSettings {
    DeviceSettings.mock()
  }

  func updateSettings(deviceId: Int, settings: DeviceSettings) async throws {
    // no-op
  }

  func registerDeviceName() async {
    // no-op
  }
}
