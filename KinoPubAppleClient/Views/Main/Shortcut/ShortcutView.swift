//
//  ShortcutView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 28.07.2023.
//

import Foundation
import SwiftUI
import KinoPubBackend
import KinoPubUI

struct ShortcutSelectionView: View {
  @Environment(\.dismiss) private var dismiss
  @Binding var shortcut: MediaShortcut

  var body: some View {
    NavigationStack {
      Form {
        Section("Sort".localized) {
          Picker("Sort".localized, selection: $shortcut) {
            ForEach(MediaShortcut.allCases) { shortcut in
              Text(shortcut.title.localized)
                .tag(shortcut)
            }
          }
          .pickerStyle(.inline)
        }
      }
      .formStyle(.grouped)
      .scrollContentBackground(.hidden)
      .background(Color.KinoPub.background)
      .navigationTitle("Sort".localized)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done".localized) {
            dismiss()
          }
        }
      }
    }
    .presentationDetents([.medium])
  }
}

struct ShortcutSelectionView_Previews: PreviewProvider {
  static var previews: some View {
    ShortcutSelectionView(shortcut: .constant(.fresh))
  }
}
