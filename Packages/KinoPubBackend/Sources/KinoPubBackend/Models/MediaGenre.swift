//
//  MediaGenre.swift
//  
//
//  Created by Kirill Kunst on 28.07.2023.
//

import Foundation

public struct MediaGenre: Codable, Identifiable, Hashable {
  public let id: Int
  public let title: String
  public let type: MediaType?
}
