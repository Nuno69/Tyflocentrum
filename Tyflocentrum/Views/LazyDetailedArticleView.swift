//
//  LazyDetailedArticleView.swift
//  Tyflocentrum
//

import Foundation
import SwiftUI

struct LazyDetailedArticleView: View {
	let summary: WPPostSummary

	@EnvironmentObject private var api: TyfloAPI
	@State private var article: Podcast?
	@State private var isLoading = false
	@State private var errorMessage: String?
	@State private var loadToken = UUID()

	private var requestTimeoutSeconds: TimeInterval {
		if ProcessInfo.processInfo.arguments.contains("UI_TESTING_FAST_TIMEOUTS") {
			return 2
		}
		return 20
	}

	var body: some View {
		ZStack {
			if let article {
				DetailedArticleView(article: article, favoriteOrigin: .post)
			} else if let message = errorMessage {
				VStack(alignment: .leading, spacing: 12) {
					Text(message)
						.foregroundColor(.secondary)

					Button("Spróbuj ponownie") {
						errorMessage = nil
						loadToken = UUID()
					}
					.accessibilityHint("Ponawia pobieranie danych.")
					.accessibilityIdentifier("postDetail.retry")
					.disabled(isLoading)
					.accessibilityHidden(isLoading)
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				.padding()
			} else {
				ProgressView("Ładowanie…")
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			}
		}
		.navigationTitle(summary.title.plainText)
		.navigationBarTitleDisplayMode(.inline)
		.task(id: loadToken) { await loadIfNeeded() }
	}

	@MainActor
	private func loadIfNeeded() async {
		guard article == nil else { return }
		await load()
	}

	@MainActor
	private func load() async {
		guard !isLoading else { return }
		isLoading = true
		errorMessage = nil
		var pendingErrorMessage: String?
		defer {
			isLoading = false
			if let pendingErrorMessage {
				errorMessage = pendingErrorMessage
			}
		}

		do {
			let loaded = try await withTimeout(requestTimeoutSeconds) {
				try await api.fetchArticle(id: summary.id)
			}
			article = loaded
		} catch {
			if error is AsyncTimeoutError {
				pendingErrorMessage = "Ładowanie trwa zbyt długo. Spróbuj ponownie."
			} else {
				pendingErrorMessage = "Nie udało się pobrać danych. Spróbuj ponownie."
			}
		}
	}
}
