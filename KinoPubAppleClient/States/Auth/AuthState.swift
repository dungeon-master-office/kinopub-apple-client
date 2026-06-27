
//
//  AuthState.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 3.08.2023.
//

import Foundation
import KinoPubBackend
import KinoPubLogging
import OSLog

/// Represents the state of the user's authentication.
enum UserState {
  case unauthorized
  case authorized
}

/// A class that manages the authentication state of the user.
@MainActor
final class AuthState: ObservableObject {
  @Published var userState: UserState = .unauthorized
  @Published var shouldShowAuthentication: Bool = false
  
  private var authService: AuthorizationService
  private var accessTokenService: AccessTokenService
  private var deviceService: DeviceService

  /// Initializes the `AuthState` with the provided services.
  /// - Parameters:
  ///   - authService: The authorization service used for authentication.
  ///   - accessTokenService: The access token service used for managing access tokens.
  ///   - deviceService: Used to deregister this device from the account on logout.
  init(authService: AuthorizationService,
       accessTokenService: AccessTokenService,
       deviceService: DeviceService) {
    self.authService = authService
    self.accessTokenService = accessTokenService
    self.deviceService = deviceService
  }
  
  /// Checks the authentication state of the user.
  func check() async {
    Logger.app.debug("Start auth state checking...")
    guard let _: AccessToken = accessTokenService.token() else {
      userState = .unauthorized
      shouldShowAuthentication = true
      Logger.app.debug("Auth state: unauthorized")
      return
    }
    
    await refreshToken()
  }
  
  private func refreshToken() async {
    Logger.app.debug("Refreshing token...")
    do {
      try await authService.refreshToken()
      userState = .authorized
      shouldShowAuthentication = false
      Logger.app.debug("Auth state: authorized")
    } catch {
      // We already have a stored token here. A connectivity failure (offline) must NOT drop us to the
      // activation screen — only a genuine server rejection of the token should. Otherwise an
      // already-activated device is asked to re-activate every time it's offline.
      if Self.isConnectivityError(error) {
        userState = .authorized
        shouldShowAuthentication = false
        Logger.app.debug("Token refresh skipped (offline); keeping existing session")
      } else {
        userState = .unauthorized
        shouldShowAuthentication = true
        Logger.app.debug("Failed to refresh token, auth state: unauthorized")
      }
    }
  }

  /// True for a transient connectivity failure (no network) vs. the server rejecting the token.
  /// Offline requests surface as `URLError`; a rejected token decodes into a `BackendError`.
  private static func isConnectivityError(_ error: Error) -> Bool {
    if let apiError = error as? APIClientError {
      switch apiError {
      case .urlError:
        return true
      case .networkError(let underlying):
        return underlying is URLError
      default:
        return false
      }
    }
    return error is URLError
  }

  /// Logs out the user. Deregisters this device from the account first (while the token is still
  /// valid), then clears the local session. Device removal is best-effort — logout proceeds even if
  /// it fails (e.g. offline).
  func logout() async {
    if let id = try? await deviceService.fetchCurrentDevice().id {
      try? await deviceService.removeDevice(id: id)
    }
    authService.logout()
    userState = .unauthorized
    shouldShowAuthentication = true
  }
}
