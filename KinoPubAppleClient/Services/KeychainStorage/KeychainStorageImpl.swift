//
//  KeychainStorageImpl.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 27.07.2023.
//

import Foundation
import KeychainAccess

final class KeychainStorageImpl: KeychainStorage {

  private lazy var keychain: Keychain = {
    return Keychain(service: "com.kunst.kinopub")
  }()

#if os(macOS)
  // On macOS the legacy keychain prompts "… wants to use the keychain" on EVERY launch: the item's
  // ACL is tied to the app's code signature, which changes between (dev) builds, so "Always Allow"
  // never sticks. For a low-risk media-client token the conventional, prompt-free approach is plain
  // UserDefaults. Any token already in the keychain is migrated once (so the user stays logged in),
  // after which the keychain is never touched again → no more prompts.
  private let defaults = UserDefaults.standard
  private let prefix = "secureStore."

  func object<Value>(for key: Key<Value>) -> Value? where Value: Decodable, Value: Encodable {
    if let data = defaults.data(forKey: prefix + key.rawValue) {
      return try? JSONDecoder().decode(Value.self, from: data)
    }
    // One-time migration from the legacy keychain (this read may prompt once, then never again).
    if let data = try? keychain.getData(key.rawValue),
       let value = try? JSONDecoder().decode(Value.self, from: data) {
      defaults.set(data, forKey: prefix + key.rawValue)
      try? keychain.remove(key.rawValue)
      return value
    }
    return nil
  }

  func setObject<Value>(_ object: Value?, for key: Key<Value>) where Value: Decodable, Value: Encodable {
    guard let object, let data = try? JSONEncoder().encode(object) else {
      defaults.removeObject(forKey: prefix + key.rawValue)
      return
    }
    defaults.set(data, forKey: prefix + key.rawValue)
  }

  func clear() {
    for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
      defaults.removeObject(forKey: key)
    }
    try? keychain.removeAll()
  }
#else
  public func object<Value>(for key: Key<Value>) -> Value? where Value: Decodable, Value: Encodable {
    do {
      guard let data = try keychain.getData(key.rawValue) else { return nil }
      return try JSONDecoder().decode(Value.self, from: data)
    } catch {
      print(error)
      return nil
    }
  }

  public func setObject<Value>(_ object: Value?, for key: Key<Value>) where Value: Decodable, Value: Encodable {
    do {
      let data = try JSONEncoder().encode(object)
      try keychain.set(data, key: key.rawValue)
    } catch {
      print(error)
    }
  }

  func clear() {
    do {
      try keychain.removeAll()
    } catch {
      print(error)
    }
  }
#endif
}
