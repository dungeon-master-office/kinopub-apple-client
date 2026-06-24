//
//  DeviceSettingsView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 25.06.2026.
//

import SwiftUI
import KinoPubBackend
import KinoPubUI

struct DeviceSettingsView: View {

  @StateObject private var model: DeviceSettingsModel

  init(model: @autoclosure @escaping () -> DeviceSettingsModel) {
    _model = StateObject(wrappedValue: model())
  }

  var body: some View {
    ZStack {
      Color.KinoPub.background.edgesIgnoringSafeArea(.all)
      if model.isLoading {
        ProgressView()
      } else {
        form
      }
    }
    .navigationTitle("Device settings".localized)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("Save".localized) {
          Task { await model.save() }
        }
        .disabled(model.isLoading || model.isSaving)
      }
    }
    .task {
      await model.load()
    }
  }

  private var form: some View {
    Form {
      if !model.deviceTitle.isEmpty {
        Section {
          LabeledContent("Device".localized, value: model.deviceTitle)
        }
      }

      Section {
        // Stream type. NOTE: these int mappings are best-effort and may need
        // adjustment to match the kino.pub API once confirmed.
        Picker("Stream type".localized, selection: $model.settings.streamingType) {
          Text("HLS").tag(0)
          Text("HLS2").tag(1)
          Text("HLS4").tag(2)
          Text("HTTP").tag(3)
        }

        // Server names aren't exposed by the API, so expose the raw index.
        Stepper(value: $model.settings.serverLocation, in: 0...20) {
          LabeledContent("Server location".localized,
                         value: "\(model.settings.serverLocation)")
        }
      }

      Section {
        Toggle("4K".localized, isOn: $model.settings.support4k)
        Toggle("HEVC".localized, isOn: $model.settings.supportHevc)
        Toggle("HDR".localized, isOn: $model.settings.supportHdr)
        Toggle("Mixed playlist".localized, isOn: $model.settings.mixedPlaylist)
        Toggle("Use SSL".localized, isOn: $model.settings.useSsl)
      } footer: {
        Text("Changes take effect within a minute".localized)
      }
    }
    .scrollContentBackground(.hidden)
    .background(Color.KinoPub.background)
  }
}

struct DeviceSettingsView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      DeviceSettingsView(model: DeviceSettingsModel(deviceService: DeviceServiceMock(),
                                                    errorHandler: ErrorHandler()))
    }
  }
}
