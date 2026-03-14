//
//  SearchView.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 19/10/2022.
//

import Foundation
import SwiftUI
import UIKit

enum SearchScope: String, CaseIterable, Identifiable {
	case podcasts
	case articles
	case all

	var id: String { rawValue }

	var title: String {
		switch self {
		case .podcasts:
			return "Podcasty"
		case .articles:
			return "Artykuły"
		case .all:
			return "Wszystko"
		}
	}
}

struct SearchItem: Identifiable {
	let kind: NewsItemKind
	let post: WPPostSummary

	var id: String {
		"\(kind.rawValue).\(post.id)"
	}

	static func sortedByRelevance(_ items: [SearchItem], query: String) -> [SearchItem] {
		let normalizedQuery = normalizeForSearch(query)
		let normalizedTokens = normalizedQuery
			.split(whereSeparator: \.isWhitespace)
			.map(String.init)
			.filter { $0.count > 1 }

		struct ScoredItem {
			let score: Int
			let item: SearchItem
		}

		func score(for item: SearchItem) -> Int {
			let normalizedTitle = normalizeForSearch(item.post.title.plainText)

			if !normalizedQuery.isEmpty, normalizedTitle.contains(normalizedQuery) {
				return 2
			}

			if !normalizedTokens.isEmpty, normalizedTokens.allSatisfy({ normalizedTitle.contains($0) }) {
				return 1
			}

			return 0
		}

		return items
			.map { ScoredItem(score: score(for: $0), item: $0) }
			.sorted { lhs, rhs in
				if lhs.score != rhs.score {
					return lhs.score > rhs.score
				}
				return isSortedBefore(lhs.item, rhs.item)
			}
			.map(\.item)
	}

	private static func normalizeForSearch(_ value: String) -> String {
		value
			.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
			.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	static func isSortedBefore(_ lhs: SearchItem, _ rhs: SearchItem) -> Bool {
		if lhs.post.date != rhs.post.date {
			return lhs.post.date > rhs.post.date
		}
		if lhs.kind.sortOrder != rhs.kind.sortOrder {
			return lhs.kind.sortOrder < rhs.kind.sortOrder
		}
		return lhs.post.id > rhs.post.id
	}
}

struct SearchView: View {
	@EnvironmentObject var api: TyfloAPI
	@EnvironmentObject private var settings: SettingsStore
	@State private var searchText = ""
	@State private var lastSearchQuery = ""
	@State private var searchScope: SearchScope = .all
	@StateObject private var viewModel = AsyncListViewModel<SearchItem>()
	@State private var playerPodcast: Podcast?

	private func dismissKeyboard() {
		UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
	}

	@MainActor
	private func search(query: String) async {
		let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return }
		lastSearchQuery = trimmed

		await viewModel.refresh {
			let items: [SearchItem]
			switch searchScope {
			case .podcasts:
				let podcasts = try await api.fetchPodcastSearchSummaries(matching: trimmed)
				items = podcasts.map { SearchItem(kind: .podcast, post: $0) }
			case .articles:
				let articles = try await api.fetchArticleSearchSummaries(matching: trimmed)
				items = articles.map { SearchItem(kind: .article, post: $0) }
			case .all:
				async let podcasts = api.fetchPodcastSearchSummaries(matching: trimmed)
				async let articles = api.fetchArticleSearchSummaries(matching: trimmed)
				let (podcastPosts, articlePosts) = try await(podcasts, articles)
				items = podcastPosts.map { SearchItem(kind: .podcast, post: $0) }
					+ articlePosts.map { SearchItem(kind: .article, post: $0) }
			}
			return SearchItem.sortedByRelevance(items, query: trimmed)
		}
		let announcement = viewModel.errorMessage
			?? (viewModel.items.isEmpty ? "Brak wyników wyszukiwania." : "Znaleziono \(viewModel.items.count) wyników.")
		UIAccessibility.post(
			notification: .announcement,
			argument: announcement
		)
	}

	private func performSearch() {
		dismissKeyboard()
		Task { await search(query: searchText) }
	}

	var body: some View {
		NavigationStack {
			List {
				Section {
					Picker("Szukaj w", selection: $searchScope) {
						ForEach(SearchScope.allCases) { scope in
							Text(scope.title)
								.tag(scope)
						}
					}
					.pickerStyle(.segmented)
					.accessibilityIdentifier("search.scope")

					TextField("Podaj frazę do wyszukania", text: $searchText)
						.accessibilityIdentifier("search.field")
						.accessibilityHint("Wpisz tekst, a następnie użyj przycisku Szukaj.")
						.submitLabel(.search)
						.onSubmit {
							performSearch()
						}

					Button("Szukaj") {
						performSearch()
					}
					.accessibilityIdentifier("search.button")
					.accessibilityHint("Wyszukuje audycje po podanej frazie.")
					.disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
					.accessibilityHidden(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
				}

				AsyncListStatusSection(
					errorMessage: viewModel.errorMessage,
					isLoading: viewModel.isLoading,
					hasLoaded: viewModel.hasLoaded,
					isEmpty: viewModel.items.isEmpty,
					emptyMessage: "Brak wyników wyszukiwania dla podanej frazy. Spróbuj użyć innych słów kluczowych.",
					loadingMessage: "Wyszukiwanie…",
					retryAction: {
						guard !lastSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
						await search(query: lastSearchQuery)
					},
					retryIdentifier: "search.retry",
					isRetryDisabled: viewModel.isLoading || lastSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
					retryHint: "Ponawia ostatnie wyszukiwanie."
				)

				if viewModel.errorMessage == nil && !viewModel.items.isEmpty {
					Section {
						ForEach(viewModel.items) { item in
							let stubPodcast = item.post.asPodcastStub()

							NavigationLink {
								switch item.kind {
								case .podcast:
									LazyDetailedPodcastView(summary: item.post)
								case .article:
									LazyDetailedArticleView(summary: item.post)
								}
							} label: {
								ShortPodcastView(
									podcast: stubPodcast,
									showsListenAction: item.kind == .podcast,
									onListen: item.kind == .podcast
										? { playerPodcast = stubPodcast }
										: nil,
									leadingSystemImageName: item.kind.systemImageName,
									accessibilityKindLabel: item.kind.label,
									accessibilityIdentifierOverride: item.kind == .article
										? "article.row.\(item.post.id)"
										: nil,
									favoriteItem: item.kind == .podcast
										? .podcast(item.post)
										: .article(summary: item.post, origin: .post)
								)
							}
							.accessibilityRemoveTraits(.isButton)
						}
					}
				}
			}
			.accessibilityIdentifier("search.list")
			.refreshable {
				let query = lastSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
				guard !query.isEmpty else { return }
				await search(query: query)
			}
			.id(settings.contentKindLabelPosition)
			.withAppMenu()
			.navigationTitle("Szukaj")
			.toolbar {
				ToolbarItem(placement: .navigationBarTrailing) {
					Button {
						dismissKeyboard()
						let query = lastSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
						if query.isEmpty {
							performSearch()
						} else {
							Task { await search(query: query) }
						}
					} label: {
						Image(systemName: "arrow.clockwise")
					}
					.accessibilityLabel("Odśwież wyniki")
					.accessibilityHint("Ponawia wyszukiwanie dla ostatniej frazy.")
					.accessibilityIdentifier("search.refresh")
					.disabled(
						viewModel.isLoading
							|| (lastSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
								&& searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
					)
					.accessibilityHidden(
						viewModel.isLoading
							|| (lastSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
								&& searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
					)
				}
			}
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
	}
}
