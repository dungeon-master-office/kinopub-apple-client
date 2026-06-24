//
//  ToggleWatchingResponse.swift
//
//
//  Created by Kirill Kunst on 11.11.2023.
//

import Foundation

public struct ToggleWatchingResponse: Codable {
  public let status: Int?
  public let watched: Int?
  public let watching: Bool?
}
