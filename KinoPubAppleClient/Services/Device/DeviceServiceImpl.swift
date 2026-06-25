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
    var title: String
    let hardware: String
    let software: String
#if os(iOS)
    title = UIDevice.current.name
    hardware = "\(UIDevice.current.model) (\(Self.machineModel))"
    software = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
#elseif os(macOS)
    title = Host.current().localizedName ?? "Mac"
    hardware = Self.machineModel
    software = "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
#else
    title = "KinoPub"
    hardware = "Apple"
    software = "Apple"
#endif
    if title.trimmingCharacters(in: .whitespaces).isEmpty {
      title = "KinoPub Apple"
    }
    let request = DeviceNotifyRequest(title: title, hardware: hardware, software: software)
    do {
      _ = try await apiClient.performRequest(with: request, decodingType: EmptyResponseData.self)
      Logger.app.debug("device notify sent: \(title) / \(hardware) / \(software)")
    } catch {
      Logger.app.debug("device notify error: \(error)")
    }
  }

  /// The hardware model identifier, e.g. "iPhone16,2" / "Mac15,3".
  private static var machineModel: String {
    var systemInfo = utsname()
    uname(&systemInfo)
    let mirror = Mirror(reflecting: systemInfo.machine)
    let identifier = mirror.children.reduce(into: "") { result, element in
      guard let value = element.value as? Int8, value != 0 else { return }
      result.append(Character(UnicodeScalar(UInt8(value))))
    }
    return identifier.isEmpty ? "Apple" : identifier
  }
}
