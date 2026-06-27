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

  func listDevices() async throws -> [ManagedDevice] {
    let request = ListDevicesRequest()
    return try await apiClient.performRequest(with: request, decodingType: DevicesData.self).devices
  }

  func removeDevice(id: Int) async throws {
    let request = RemoveDeviceRequest(id: id)
    _ = try await apiClient.performRequest(with: request, decodingType: EmptyResponseData.self)
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

  func syncCapabilities() async {
    // Match the kino.pub device profile to what this hardware can DECODE. When HEVC decode is
    // available we advertise HEVC + 4K (kino.pub then serves HEVC + HDR10; AVPlayer plays it, tone-
    // mapping to SDR displays like the base iPad), AND turn on mixedPlaylist so the master also
    // carries h264 variants — AVPlayer can't open an HEVC-only HDR master (error -11868/-17223,
    // the crossed-out play), so the fallback guarantees playback while still allowing HDR where the
    // device can use the HEVC variant. When HEVC isn't decodable, turn all three off (plain h264).
    let hevc = DeviceCapabilities.supportsHEVC
    do {
      let device = try await fetchCurrentDevice()
      var settings = try await fetchSettings(deviceId: device.id)
      guard settings.supportHevc != hevc
              || settings.support4k != hevc
              || settings.supportHdr != hevc
              || settings.mixedPlaylist != hevc else { return }
      settings.supportHevc = hevc
      settings.support4k = hevc
      // Advertise HDR too so kino.pub includes HDR/Dolby-Vision renditions; the native player picks
      // HDR on capable displays and tone-maps to SDR otherwise.
      settings.supportHdr = hevc
      settings.mixedPlaylist = hevc
      try await updateSettings(deviceId: device.id, settings: settings)
      Logger.app.debug("device capabilities synced to HEVC-decodable=\(hevc) (+HDR +mixedPlaylist)")
    } catch {
      Logger.app.debug("syncCapabilities error: \(error)")
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
