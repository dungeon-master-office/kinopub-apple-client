//
//  DeviceServiceImpl.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 25.06.2026.
//

import Foundation
import KinoPubBackend
import OSLog
import KinoPubLogging
#if os(iOS)
import UIKit
#endif

final class DeviceServiceImpl: DeviceService {

  private var apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  func fetchCurrentDevice() async throws -> DeviceInfo {
    let request = DeviceInfoRequest()
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: DeviceInfoData.self)
    return response.device
  }

  func fetchSettings(deviceId: Int) async throws -> DeviceSettings {
    let request = DeviceSettingsRequest(id: deviceId)
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: DeviceSettingsData.self)
    return response.settings
  }

  func updateSettings(deviceId: Int, settings: DeviceSettings) async throws {
    let request = UpdateDeviceSettingsRequest(id: deviceId, settings: settings)
    _ = try await apiClient.performRequest(with: request,
                                           decodingType: EmptyResponseData.self)
  }

  func registerDeviceName() async {
    let title: String
    let software: String
#if os(iOS)
    title = UIDevice.current.name
    software = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
#elseif os(macOS)
    title = Host.current().localizedName ?? "Mac"
    software = "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
#else
    title = "KinoPub"
    software = "Apple"
#endif
    let request = DeviceNotifyRequest(title: title, hardware: "KinoPub Apple", software: software)
    do {
      _ = try await apiClient.performRequest(with: request, decodingType: EmptyResponseData.self)
    } catch {
      Logger.app.debug("device notify error: \(error)")
    }
  }
}
