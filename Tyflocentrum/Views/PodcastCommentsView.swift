//
//  PodcastCommentsView.swift
//  Tyflocentrum
//

import SwiftUI

struct PodcastCommentsView: View {
	let postID: Int
	let postTitle: String

	@EnvironmentObject private var api: TyfloAPI
	@StateObject private var viewModel = AsyncListViewModel<Comment>()

	private var requestTimeoutSeconds: TimeInterval {
		if ProcessInfo.processInfo.arguments.contains("UI_TESTING_FAST_TIMEOUTS") {
			return 2
		}
		return 15
	}

	var body: some View {
		List {
			AsyncListStatusSection(
				errorMessage: viewModel.errorMessage,
				isLoading: viewModel.isLoading,
				hasLoaded: viewModel.hasLoaded,
				isEmpty: viewModel.items.isEmpty,
				emptyMessage: "Brak komentarzy.",
				retryAction: { await viewModel.refresh(fetchComments, timeoutSeconds: requestTimeoutSeconds) },
				retryIdentifier: "comments.retry",
				isRetryDisabled: viewModel.isLoading,
				retryHint: "Ponawia pobieranie komentarzy."
			)

			ForEach(viewModel.items) { comment in
				NavigationLink {
					PodcastCommentDetailView(authorName: comment.authorName, htmlBody: comment.content.rendered)
				} label: {
					PodcastCommentRowView(authorName: comment.authorName)
				}
				.accessibilityRemoveTraits(.isButton)
				.accessibilityIdentifier("comment.row.\(comment.id)")
			}
		}
		.accessibilityIdentifier("comments.list")
		.refreshable {
			await viewModel.refresh(fetchComments, timeoutSeconds: requestTimeoutSeconds)
		}
		.task {
			await viewModel.loadIfNeeded(fetchComments, timeoutSeconds: requestTimeoutSeconds)
		}
		.navigationTitle("Komentarze")
		.navigationBarTitleDisplayMode(.inline)
		.accessibilityHint("Komentarze do wpisu: \(postTitle)")
	}

	private func fetchComments() async throws -> [Comment] {
		try await api.fetchComments(forPostID: postID)
	}
}

private struct PodcastCommentRowView: View {
	let authorName: String

	var body: some View {
		HStack {
			Text(authorName)
				.foregroundColor(.primary)
			Spacer()
		}
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(authorName)
		.accessibilityHint("Dwukrotnie stuknij, aby przeczytać komentarz.")
	}
}

private struct PodcastCommentDetailView: View {
	let authorName: String
	let htmlBody: String

	var body: some View {
		SafeHTMLView(
			htmlBody: htmlBody,
			baseURL: URL(string: "https://tyflopodcast.net"),
			accessibilityIdentifier: "comment.content"
		)
		.navigationTitle(authorName)
		.navigationBarTitleDisplayMode(.inline)
	}
}
