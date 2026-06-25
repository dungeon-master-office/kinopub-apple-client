//
//  CommentsView.swift
//  KinoPubAppleClient
//
//  Comments for a film/episode. Presented as a sheet from MediaItemView.
//

import SwiftUI
import KinoPubUI
import KinoPubBackend
import OSLog
import KinoPubLogging

struct CommentsView: View {

  let mediaId: Int

  @Environment(\.dismiss) private var dismiss
  @State private var comments: [Comment] = []
  @State private var isLoading: Bool = true
  @State private var failed: Bool = false

  private var contentService: VideoContentService { AppContext.shared.contentService }

  var body: some View {
    NavigationStack {
      Group {
        if isLoading {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if comments.isEmpty {
          KinoPubUI.EmptyStateView(
            systemImage: "bubble.left.and.bubble.right",
            title: failed ? "Couldn't load comments".localized : "No comments yet".localized,
            message: failed ? nil : "Be the first to discuss this title".localized
          )
        } else {
          ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
              ForEach(comments) { comment in
                CommentRow(comment: comment)
                Divider().background(Color.white.opacity(0.08))
              }
            }
            .padding(.vertical, 8)
          }
        }
      }
      .background(Color.KinoPub.background)
      .navigationTitle("Comments".localized)
      #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done".localized) { dismiss() }
        }
      }
      .task { await load() }
    }
  }

  private func load() async {
    isLoading = true
    failed = false
    do {
      let response = try await contentService.fetchComments(for: mediaId)
      comments = response.comments.filter { $0.deleted != true }
    } catch {
      Logger.app.error("[COMMENTS] Failed to load comments for \(mediaId): \(error)")
      failed = true
      comments = []
    }
    isLoading = false
  }
}

private struct CommentRow: View {
  let comment: Comment

  private var avatarURL: URL? {
    guard let avatar = comment.user.avatar, !avatar.isEmpty else { return nil }
    return URL(string: avatar)
  }

  private var formattedDate: String {
    let date = Date(timeIntervalSince1970: TimeInterval(comment.created))
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }

  /// Rating arrives as a string ("0" means no rating).
  private var ratingValue: Int? {
    guard let rating = comment.rating, let value = Int(rating), value != 0 else { return nil }
    return value
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .center, spacing: 10) {
        avatar
        VStack(alignment: .leading, spacing: 2) {
          Text(comment.user.name)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.KinoPub.text)
          Text(formattedDate)
            .font(.system(size: 11))
            .foregroundStyle(Color.KinoPub.subtitle)
        }
        Spacer()
        if let rating = ratingValue {
          HStack(spacing: 2) {
            Image(systemName: rating > 0 ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
            Text("\(rating > 0 ? "+" : "")\(rating)")
          }
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(rating > 0 ? Color.KinoPub.accent : Color.red.opacity(0.8))
        }
      }
      Text(comment.message)
        .font(.system(size: 14))
        .foregroundStyle(Color.KinoPub.text)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
    // Threaded replies are indented by depth.
    .padding(.leading, CGFloat(min(comment.depth ?? 0, 4)) * 16)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder
  private var avatar: some View {
    AsyncImage(url: avatarURL) { image in
      image.resizable().aspectRatio(contentMode: .fill)
    } placeholder: {
      Circle()
        .fill(Color.KinoPub.accent.opacity(0.25))
        .overlay(
          Text(String(comment.user.name.prefix(1)).uppercased())
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Color.KinoPub.accent)
        )
    }
    .frame(width: 36, height: 36)
    .clipShape(Circle())
  }
}
