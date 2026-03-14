//
//  DetailedCategoryView.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 10/11/2022.
//

import SwiftUI

struct DetailedCategoryView: View {
	let category: Category
	@EnvironmentObject var api: TyfloAPI
	@StateObject private var viewModel = PostSummariesFeedViewModel(perPage: 40)
	@State private var playerPodcast: Podcast?
	var body: some View {
		List {
			AsyncListStatusSection(
				errorMessage: viewModel.errorMessage,
				isLoading: viewModel.isLoading,
				hasLoaded: viewModel.hasLoaded,
				isEmpty: viewModel.items.isEmpty,
				emptyMessage: "Brak audycji w tej kategorii.",
				retryAction: { await viewModel.refresh(fetchPage: fetchPage) },
				retryIdentifier: "categoryPodcasts.retry",
				isRetryDisabled: viewModel.isLoading
			)

			ForEach(viewModel.items) { summary in
				let stubPodcast = summary.asPodcastStub()
				NavigationLink {
					LazyDetailedPodcastView(summary: summary)
				} label: {
					ShortPodcastView(
						podcast: stubPodcast,
						onListen: {
							playerPodcast = stubPodcast
						},
						favoriteItem: .podcast(summary)
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
		.accessibilityIdentifier("categoryPodcasts.list")
		.refreshable {
			await viewModel.refresh(fetchPage: fetchPage)
		}
		.task {
			await viewModel.loadIfNeeded(fetchPage: fetchPage)
		}
		.navigationTitle(category.name)
		.navigationBarTitleDisplayMode(.inline)
		.background(
			NavigationLink(
				destination: Group {
					if let podcast = playerPodcast {
						PodcastPlayerView(podcast: podcast)
					} else {
						EmptyView()
					}
				},
				isActive: Binding(
					get: { playerPodcast != nil },
					set: { isActive in
						if !isActive {
							playerPodcast = nil
						}
					}
				)
			) {
				EmptyView()
			}
			.hidden()
		)
	}

	private func fetchPage(page: Int, perPage: Int) async throws -> TyfloAPI.WPPage<WPPostSummary> {
		try await api.fetchPodcastSummariesPage(page: page, perPage: perPage, categoryID: category.id)
	}
}
