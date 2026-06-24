//
//  ToggleBookmarkFolderRequest.swift
//
//
//  Created by Kirill Kunst on 11.11.2023.
//

import Foundation

public struct ToggleBookmarkFolderRequest: Endpoint {

  public var item: Int
  public var folder: Int

  public init(item: Int, folder: Int) {
    self.item = item
    self.folder = folder
  }

  public var path: String {
    "/v1/bookmarks/toggle-item"
  }

  public var method: String {
    "POST"
  }

  public var parameters: [String: Any]? {
    [
      "item": item,
      "folder": folder
    ]
  }

  public var headers: [String: String]? {
    nil
  }

  public var forceSendAsGetParams: Bool { true }
}
