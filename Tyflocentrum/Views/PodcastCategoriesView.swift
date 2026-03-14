//
//  PodcastCategoriesView.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 19/10/2022.
//

import Foundation
import SwiftUI

struct PodcastCategoriesView: View {
	@EnvironmentObject var api: TyfloAPI
	@StateObject private var viewModel = PagedFeedViewModel<Category>(perPage: 100)
	var body: some View {
		NavigationStack {
			List {
				Section {
					NavigationLink {
						AllPodcastsView()
					} label: {
						AllCategoriesRowView(title: "Wszystkie kategorie", accessibilityIdentifier: "podcastCategories.all")
					}
					.accessibilityRemoveTraits(.isButton)
				}

				AsyncListStatusSection(
					errorMessage: viewModel.errorMessage,
					isLoading: viewModel.isLoading,
					hasLoaded: viewModel.hasLoaded,
					isEmpty: viewModel.items.isEmpty,
					emptyMessage: "Brak kategorii podcastów.",
					retryAction: { await viewModel.refresh(fetchPage: fetchPage) },
					retryIdentifier: "podcastCategories.retry",
					isRetryDisabled: viewModel.isLoading
				)

				ForEach(viewModel.items) { item in
					NavigationLink {
						DetailedCategoryView(category: item)
					} label: {
						ShortCategoryView(category: item)
					}
					.accessibilityRemoveTraits(.isButton)
					.onAppear {
						guard item.id == viewModel.items.last?.id else { return }
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
							ProgressView("Ładowanie kolejnych kategorii…")
						}
					}
				}
			}
			.accessibilityIdentifier("podcastCategories.list")
			.refreshable {
				await viewModel.refresh(fetchPage: fetchPage)
			}
			.task {
				await viewModel.loadIfNeeded(fetchPage: fetchPage)
			}
			.withAppMenu()
			.navigationTitle("Podcasty")
		}
	}

	private func fetchPage(page: Int, perPage: Int) async throws -> TyfloAPI.WPPage<Category> {
		try await api.fetchPodcastCategoriesPage(page: page, perPage: perPage)
	}
}

struct AllPodcastsView: View {
	@EnvironmentObject private var api: TyfloAPI
	@StateObject private var viewModel = PostSummariesFeedViewModel()
	@State private var playerPodcast: Podcast?

	var body: some View {
		List {
			AsyncListStatusSection(
				errorMessage: viewModel.errorMessage,
				isLoading: viewModel.isLoading,
				hasLoaded: viewModel.hasLoaded,
				isEmpty: viewModel.items.isEmpty,
				emptyMessage: "Brak podcastów.",
				retryAction: { await viewModel.refresh(fetchPage: fetchPage) },
				retryIdentifier: "allPodcasts.retry",
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
		.refreshable {
			await viewModel.refresh(fetchPage: fetchPage)
		}
		.task {
			await viewModel.loadIfNeeded(fetchPage: fetchPage)
		}
		.navigationTitle("Wszystkie podcasty")
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
		try await api.fetchPodcastSummariesPage(page: page, perPage: perPage)
	}
}
