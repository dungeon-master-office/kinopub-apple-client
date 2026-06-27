//
//  SectionVisibilityStore.swift
//  KinoPubAppleClient
//
//  Persisted show/hide state for the library/other sections in the sidebar and the iPhone "More"
//  tab. Films, Serials and Collections can't be hidden. Order is unchanged — this only toggles
//  visibility; the editing UI lives in Profile → Sections.
//

import Foundation
import Combine

final class SectionVisibilityStore: ObservableObject {
  static let shared = SectionVisibilityStore()

  private let key = "hiddenSectionIDs"
  @Published private(set) var hidden: Set<String>

  private init() {
    hidden = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
  }

  /// Sections that must always be visible (can't be toggled off).
  private static let forced: Set<String> = ["category-movie", "category-serial", "collections"]

  /// The sections the user can actually show/hide, grouped like the sidebar (order preserved).
  static var editableLibrary: [SidebarItem] {
    SidebarItem.libraryCategories.map { SidebarItem.category($0) }
      + CatalogPreset.visible.map { SidebarItem.preset($0) }
      + [.sport, .collections]
  }
  static let editableOther: [SidebarItem] = [.newEpisodes, .watching, .bookmarks, .history, .downloads]

  func canHide(_ item: SidebarItem) -> Bool { !Self.forced.contains(item.id) }

  func isVisible(_ item: SidebarItem) -> Bool { !hidden.contains(item.id) }

  func setVisible(_ item: SidebarItem, _ visible: Bool) {
    guard canHide(item) else { return }
    if visible { hidden.remove(item.id) } else { hidden.insert(item.id) }
    UserDefaults.standard.set(Array(hidden), forKey: key)
  }
}
