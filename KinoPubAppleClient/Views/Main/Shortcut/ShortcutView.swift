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

/// The catalog sort picker (moved out of the filter modal — it's now the primary sort control).
struct SortSelectionView: View {
  @Environment(\.dismiss) private var dismiss
  @Binding var sort: SortOption

  var body: some View {
    NavigationStack {
      Form {
        ForEach(SortOption.allCases) { option in
          Button {
            sort = option
            dismiss()
          } label: {
            HStack {
              Text(option.titleKey.localized)
                .foregroundStyle(Color.KinoPub.text)
              Spacer()
              if sort == option {
                Image(systemName: "checkmark")
                  .foregroundStyle(Color.KinoPub.accent)
                  .fontWeight(.semibold)
              }
            }
          }
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

struct SortSelectionView_Previews: PreviewProvider {
  static var previews: some View {
    SortSelectionView(sort: .constant(.updated))
  }
}
