//
//  ChannelEPGRow.swift
//  KinoPubAppleClient
//
//  A single row in the Sport EPG list: channel logo + title combined with its programme
//  guide — the programme on air now (title + time range + progress) and what's next.
//

import SwiftUI
import KinoPubUI
import KinoPubBackend

/// Shared, lazily-built formatter for programme times ("12:00"). Allocating one per row in
/// `body` would be wasteful, so the whole Sport screen reuses this single instance.
enum EPGTimeFormat {
  static let time: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    formatter.dateStyle = .none
    return formatter
  }()

  /// Date + time (relative, e.g. "Today at 14:30" / "5 Jul at 14:30") — for the "guide updated"
  /// caption, since the guide now refreshes at most once a day so the date matters.
  static let dateTime: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    formatter.dateStyle = .medium
    formatter.doesRelativeDateFormatting = true
    return formatter
  }()

  /// "12:00 – 13:30" in the user's local timezone.
  static func range(_ start: Date, _ stop: Date) -> String {
    "\(time.string(from: start)) – \(time.string(from: stop))"
  }
}

/// A channel row that merges the channel (logo + title) with its now/next programme info.
/// `current`/`next` are looked up by the parent against a ticking `now`, so progress advances.
struct ChannelEPGRow: View {
  let channel: TVChannel
  let current: EPGProgram?
  let next: EPGProgram?
  let now: Date
  let isSelected: Bool
  /// While the guide is still downloading, show a loading hint instead of "no programme".
  var isLoadingGuide: Bool = false

  var body: some View {
    HStack(spacing: 12) {
      ChannelArtwork(logo: channel.logo)
        .frame(width: 76, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 6, style: .continuous)
            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )

      VStack(alignment: .leading, spacing: 4) {
        Text(channel.title)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(Color.KinoPub.text)
          .lineLimit(1)

        programmeInfo
      }

      Spacer(minLength: 0)
    }
    .contentShape(Rectangle())
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(isSelected ? Color.KinoPub.selectionBackground : Color.clear)
    )
  }

  /// Now/next block. Degrades gracefully: with no EPG match it shows a single muted line.
  @ViewBuilder
  private var programmeInfo: some View {
    if let current {
      // On air now: title, time range, and a thin progress bar.
      HStack(spacing: 6) {
        Text("On air".localized.uppercased())
          .font(.system(size: 10, weight: .heavy))
          .foregroundStyle(Color.KinoPub.subtitle)
        Text(current.title)
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(Color.KinoPub.text)
          .lineLimit(1)
      }
      Text(EPGTimeFormat.range(current.start, current.stop))
        .font(.system(size: 11))
        .foregroundStyle(Color.KinoPub.subtitle)
      EPGProgressBar(progress: current.progress(at: now))
        .frame(height: 3)
        .padding(.top, 1)

      if let next {
        nextLine(next)
      }
    } else if let next {
      // Nothing on air, but we know what's coming up.
      nextLine(next)
    } else if isLoadingGuide {
      // Guide still downloading — don't imply there's no programme.
      HStack(spacing: 6) {
        ProgressView().controlSize(.mini)
        Text("Loading guide".localized)
          .font(.system(size: 12))
          .foregroundStyle(Color.KinoPub.subtitle)
      }
    } else {
      Text("No programme info".localized)
        .font(.system(size: 12))
        .foregroundStyle(Color.KinoPub.subtitle)
    }
  }

  /// "Next: <title> · 13:30"
  private func nextLine(_ program: EPGProgram) -> some View {
    (Text("\("Next".localized): ").foregroundColor(Color.KinoPub.subtitle)
     + Text(program.title).foregroundColor(Color.KinoPub.text)
     + Text(" · \(EPGTimeFormat.time.string(from: program.start))").foregroundColor(Color.KinoPub.subtitle))
      .font(.system(size: 12))
      .lineLimit(1)
  }
}

/// A thin rounded progress bar (0...1) used for the on-air programme.
struct EPGProgressBar: View {
  let progress: Double

  var body: some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        Capsule()
          .fill(Color.KinoPub.skeleton)
        Capsule()
          .fill(Color.KinoPub.subtitle)
          .frame(width: geo.size.width * min(1, max(0, progress)))
      }
    }
  }
}
