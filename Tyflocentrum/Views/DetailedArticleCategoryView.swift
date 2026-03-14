//
//  DetailedArticleCategoryView.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 12/11/2022.
//

import Foundation
import SwiftUI

struct DetailedArticleCategoryView: View {
	let category: Category
	@EnvironmentObject var api: TyfloAPI
	@StateObject private var viewModel = PostSummariesFeedViewModel(perPage: 40)
	var body: some View {
		List {
			AsyncListStatusSection(
				errorMessage: viewModel.errorMessage,
				isLoading: viewModel.isLoading,
				hasLoaded: viewModel.hasLoaded,
				isEmpty: viewModel.items.isEmpty,
				emptyMessage: "Brak artykułów w tej kategorii.",
				retryAction: { await viewModel.refresh(fetchPage: fetchPage) },
				retryIdentifier: "categoryArticles.retry",
				isRetryDisabled: viewModel.isLoading
			)

			ForEach(viewModel.items) { summary in
				NavigationLink {
					LazyDetailedArticleView(summary: summary)
				} label: {
					ShortPodcastView(
						podcast: summary.asPodcastStub(),
						showsListenAction: false,
						favoriteItem: .article(summary: summary, origin: .post)
					)
				}
				.accessibilityRemoveTraits(.isButton)
				.onAppear {
					guard summary.id == viewModel.items.last?.id else { return }
					Task { await viewModel.loadMore(fetchPage: fetchPage) }
				}
			}

			if viewModel.errorMessage == nil, viewModel.hasLoaded {
				if let loadMoreError = viewModel.loadMoreErrorMessage {
					Section {
						Text(loadMoreError)
							.foregroundColor(.secondary)

						Button("Spróbuj ponownie") {
							Task { await viewModel.loadMore(fetchPage: fetchPage) }
						}
						.disabled(viewModel.isLoadingMore)
						.accessibilityHidden(viewModel.isLoadingMore)
					}
				} else if viewModel.isLoadingMore {
					Section {
						ProgressView("Ładowanie starszych treści…")
					}
				}
			}
		}
		.accessibilityIdentifier("categoryArticles.list")
		.refreshable {
			await viewModel.refresh(fetchPage: fetchPage)
		}
		.task {
			await viewModel.loadIfNeeded(fetchPage: fetchPage)
		}
		.navigationTitle(category.name)
		.navigationBarTitleDisplayMode(.inline)
	}

	private func fetchPage(page: Int, perPage: Int) async throws -> TyfloAPI.WPPage<WPPostSummary> {
		try await api.fetchArticleSummariesPage(page: page, perPage: perPage, categoryID: category.id)
	}
}
