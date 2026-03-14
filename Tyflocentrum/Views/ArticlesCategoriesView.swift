//
//  ArticlesCategoriesView.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 19/10/2022.
//

import Foundation
import SwiftUI

struct ArticlesCategoriesView: View {
	@EnvironmentObject var api: TyfloAPI
	@StateObject private var viewModel = PagedFeedViewModel<Category>(perPage: 100)
	var body: some View {
		NavigationStack {
			List {
				Section {
					NavigationLink {
						TyfloSwiatMagazineView()
					} label: {
						MagazineRowView(
							title: "Czasopismo TyfloŚwiat",
							accessibilityIdentifier: "articleCategories.magazine"
						)
					}
					.accessibilityRemoveTraits(.isButton)

					NavigationLink {
						AllArticlesView()
					} label: {
						AllCategoriesRowView(title: "Wszystkie kategorie", accessibilityIdentifier: "articleCategories.all")
					}
					.accessibilityRemoveTraits(.isButton)
				}

				AsyncListStatusSection(
					errorMessage: viewModel.errorMessage,
					isLoading: viewModel.isLoading,
					hasLoaded: viewModel.hasLoaded,
					isEmpty: viewModel.items.isEmpty,
					emptyMessage: "Brak kategorii artykułów.",
					retryAction: { await viewModel.refresh(fetchPage: fetchPage) },
					retryIdentifier: "articleCategories.retry",
					isRetryDisabled: viewModel.isLoading
				)

				ForEach(viewModel.items) { item in
					NavigationLink {
						DetailedArticleCategoryView(category: item)
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
			.accessibilityIdentifier("articleCategories.list")
			.refreshable {
				await viewModel.refresh(fetchPage: fetchPage)
			}
			.task {
				await viewModel.loadIfNeeded(fetchPage: fetchPage)
			}
			.withAppMenu()
			.navigationTitle("Artykuły")
		}
	}

	private func fetchPage(page: Int, perPage: Int) async throws -> TyfloAPI.WPPage<Category> {
		try await api.fetchArticleCategoriesPage(page: page, perPage: perPage)
	}
}

private struct MagazineRowView: View {
	let title: String
	let accessibilityIdentifier: String

	var body: some View {
		HStack {
			Text(title)
				.font(.headline)
				.foregroundColor(.primary)
			Spacer()
		}
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(title)
		.accessibilityHint("Dwukrotnie stuknij, aby przeglądać numery czasopisma.")
		.accessibilityIdentifier(accessibilityIdentifier)
	}
}

struct AllArticlesView: View {
	@EnvironmentObject private var api: TyfloAPI
	@StateObject private var viewModel = PostSummariesFeedViewModel()

	var body: some View {
		List {
			AsyncListStatusSection(
				errorMessage: viewModel.errorMessage,
				isLoading: viewModel.isLoading,
				hasLoaded: viewModel.hasLoaded,
				isEmpty: viewModel.items.isEmpty,
				emptyMessage: "Brak artykułów.",
				retryAction: { await viewModel.refresh(fetchPage: fetchPage) },
				retryIdentifier: "allArticles.retry",
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
		.navigationTitle("Wszystkie artykuły")
		.navigationBarTitleDisplayMode(.inline)
	}

	private func fetchPage(page: Int, perPage: Int) async throws -> TyfloAPI.WPPage<WPPostSummary> {
		try await api.fetchArticleSummariesPage(page: page, perPage: perPage)
	}
}

private struct TyfloSwiatMagazineView: View {
	@EnvironmentObject private var api: TyfloAPI
	@StateObject private var viewModel = AsyncListViewModel<WPPostSummary>()
	private let magazineRootPageID = 1409
	private static let issuesCacheKey = "magazine.issues.cache.v1"
	private let loadTimeoutSeconds: TimeInterval = 15

	private var issuesByYear: [(year: Int, issues: [WPPostSummary])] {
		let grouped = Dictionary(grouping: viewModel.items) { issue in
			TyfloSwiatMagazineParsing.parseIssueNumberAndYear(from: issue.title.plainText).year ?? 0
		}
		let sortedYears = grouped.keys.sorted(by: >)
		return sortedYears.compactMap { year in
			guard let issues = grouped[year] else { return nil }
			return (year: year, issues: issues)
		}
	}

	var body: some View {
		List {
			AsyncListStatusSection(
				errorMessage: viewModel.errorMessage,
				isLoading: viewModel.isLoading,
				hasLoaded: viewModel.hasLoaded,
				isEmpty: viewModel.items.isEmpty,
				emptyMessage: "Brak numerów czasopisma.",
				retryAction: { await viewModel.refresh(fetchIssues, timeoutSeconds: loadTimeoutSeconds) },
				retryIdentifier: "magazine.retry",
				isRetryDisabled: viewModel.isLoading
			)

			ForEach(issuesByYear, id: \.year) { group in
				NavigationLink {
					TyfloSwiatMagazineYearView(year: group.year, issues: group.issues)
				} label: {
					TyfloSwiatMagazineYearRowView(year: group.year, count: group.issues.count)
				}
				.accessibilityRemoveTraits(.isButton)
			}
		}
		.accessibilityIdentifier("magazine.years.list")
		.refreshable {
			await viewModel.refresh(fetchIssues, timeoutSeconds: loadTimeoutSeconds)
		}
		.task {
			viewModel.seed(loadCachedIssues())
			await viewModel.loadIfNeeded(fetchIssues, timeoutSeconds: loadTimeoutSeconds)
		}
		.navigationTitle("Czasopismo TyfloŚwiat")
	}

	private func fetchIssues() async throws -> [WPPostSummary] {
		do {
			let issues = try await api.fetchTyfloswiatPageSummaries(parentPageID: magazineRootPageID, perPage: 100)
			if !issues.isEmpty {
				storeCachedIssues(issues)
				return issues
			}
		} catch {
			// Fallback below.
		}

		let roots = try await api.fetchTyfloswiatPages(slug: "czasopismo", perPage: 1)
		let rootID = roots.first?.id ?? magazineRootPageID
		let issues = try await api.fetchTyfloswiatPageSummaries(parentPageID: rootID, perPage: 100)
		if !issues.isEmpty {
			storeCachedIssues(issues)
		}
		return issues
	}

	private func loadCachedIssues() -> [WPPostSummary] {
		guard let data = UserDefaults.standard.data(forKey: Self.issuesCacheKey) else { return [] }
		return (try? JSONDecoder().decode([WPPostSummary].self, from: data)) ?? []
	}

	private func storeCachedIssues(_ issues: [WPPostSummary]) {
		guard let data = try? JSONEncoder().encode(issues) else { return }
		UserDefaults.standard.set(data, forKey: Self.issuesCacheKey)
	}
}

private struct TyfloSwiatMagazineYearRowView: View {
	let year: Int
	let count: Int

	var body: some View {
		HStack {
			Text("\(year)")
				.font(.headline)
				.foregroundColor(.primary)
			Spacer()
			Text("\(count)")
				.font(.subheadline)
				.foregroundColor(.secondary)
		}
		.accessibilityElement(children: .ignore)
		.accessibilityLabel("\(year)")
		.accessibilityValue("\(count) numerów")
		.accessibilityHint("Dwukrotnie stuknij, aby wyświetlić numery z tego roku.")
		.accessibilityIdentifier("magazine.year.\(year)")
	}
}

private struct TyfloSwiatMagazineYearView: View {
	let year: Int
	let issues: [WPPostSummary]

	private var sortedIssues: [WPPostSummary] {
		issues.sorted { lhs, rhs in
			let left = TyfloSwiatMagazineParsing.parseIssueNumberAndYear(from: lhs.title.plainText).number ?? -1
			let right = TyfloSwiatMagazineParsing.parseIssueNumberAndYear(from: rhs.title.plainText).number ?? -1
			if left != right { return left > right }
			if lhs.date != rhs.date { return lhs.date > rhs.date }
			return lhs.id > rhs.id
		}
	}

	var body: some View {
		List {
			ForEach(sortedIssues) { issue in
				NavigationLink {
					TyfloSwiatMagazineIssueView(issueSummary: issue)
				} label: {
					ShortPodcastView(
						podcast: issue.asPodcastStub(),
						showsListenAction: false,
						accessibilityKindLabel: "Numer",
						accessibilityIdentifierOverride: "magazine.issue.\(issue.id)",
						favoriteItem: .article(summary: issue, origin: .page)
					)
				}
				.accessibilityRemoveTraits(.isButton)
			}
		}
		.accessibilityIdentifier("magazine.issues.list")
		.navigationTitle("\(year)")
		.navigationBarTitleDisplayMode(.inline)
	}
}

private struct TyfloSwiatMagazineIssueView: View {
	let issueSummary: WPPostSummary

	@EnvironmentObject private var api: TyfloAPI
	@Environment(\.openURL) private var openURL

	@State private var issue: Podcast?
	@State private var tocItems: [WPPostSummary] = []
	@State private var pdfURL: URL?
	@State private var isLoading = false
	@State private var errorMessage: String?

	var body: some View {
		Group {
			if let issue {
				if tocItems.isEmpty {
					DetailedArticleView(article: issue, favoriteOrigin: .page)
				} else {
					List {
						if let pdfURL {
							Section {
								Button("Pobierz PDF") {
									openURL(pdfURL)
								}
								.accessibilityIdentifier("magazine.issue.pdf")
								.accessibilityHint("Otwiera plik PDF w systemowym podglądzie.")
							}
						}

						Section(header: Text("Spis treści")) {
							ForEach(tocItems) { item in
								NavigationLink {
									LazyDetailedTyfloswiatPageView(summary: item)
								} label: {
									ShortPodcastView(
										podcast: item.asPodcastStub(),
										showsListenAction: false,
										accessibilityKindLabel: "Artykuł",
										accessibilityIdentifierOverride: "magazine.article.\(item.id)",
										favoriteItem: .article(summary: item, origin: .page)
									)
								}
								.accessibilityRemoveTraits(.isButton)
							}
						}
					}
					.accessibilityIdentifier("magazine.toc.list")
				}
			} else if let errorMessage {
				AsyncListStatusSection(
					errorMessage: errorMessage,
					isLoading: isLoading,
					hasLoaded: true,
					isEmpty: true,
					emptyMessage: "",
					retryAction: { await load() },
					retryIdentifier: "magazine.issue.retry",
					isRetryDisabled: isLoading
				)
			} else {
				AsyncListStatusSection(
					errorMessage: nil,
					isLoading: true,
					hasLoaded: false,
					isEmpty: true,
					emptyMessage: ""
				)
			}
		}
		.navigationTitle(issueSummary.title.plainText)
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			if let pdfURL, tocItems.isEmpty {
				ToolbarItem(placement: .navigationBarTrailing) {
					Button {
						openURL(pdfURL)
					} label: {
						Image(systemName: "arrow.down.doc")
					}
					.accessibilityLabel("Pobierz PDF")
					.accessibilityIdentifier("magazine.issue.pdf.toolbar")
				}
			}
		}
		.task {
			await loadIfNeeded()
		}
	}

	private func loadIfNeeded() async {
		guard issue == nil else { return }
		guard errorMessage == nil else { return }
		await load()
	}

	private func load() async {
		guard !isLoading else { return }
		isLoading = true
		defer { isLoading = false }

		errorMessage = nil
		do {
			async let page = api.fetchTyfloswiatPage(id: issueSummary.id)
			async let children = api.fetchTyfloswiatPageSummaries(parentPageID: issueSummary.id, perPage: 100)

			let (loadedPage, loadedChildren) = try await(page, children)
			guard !Task.isCancelled else { return }

			issue = loadedPage
			pdfURL = TyfloSwiatMagazineParsing.extractFirstPDFURL(from: loadedPage.content.rendered)
			tocItems = TyfloSwiatMagazineParsing.orderedTableOfContents(
				children: loadedChildren,
				issueHTML: loadedPage.content.rendered
			)
		} catch {
			guard !Task.isCancelled else { return }
			errorMessage = "Nie udało się pobrać danych. Spróbuj ponownie."
		}
	}
}

struct LazyDetailedTyfloswiatPageView: View {
	let summary: WPPostSummary

	@EnvironmentObject private var api: TyfloAPI
	@State private var page: Podcast?
	@State private var isLoading = false
	@State private var errorMessage: String?

	var body: some View {
		Group {
			if let page {
				DetailedArticleView(article: page, favoriteOrigin: .page)
			} else if let errorMessage {
				AsyncListStatusSection(
					errorMessage: errorMessage,
					isLoading: isLoading,
					hasLoaded: true,
					isEmpty: true,
					emptyMessage: "",
					retryAction: { await load() }
				)
			} else {
				AsyncListStatusSection(
					errorMessage: nil,
					isLoading: true,
					hasLoaded: false,
					isEmpty: true,
					emptyMessage: ""
				)
			}
		}
		.navigationTitle(summary.title.plainText)
		.navigationBarTitleDisplayMode(.inline)
		.task {
			await loadIfNeeded()
		}
	}

	private func loadIfNeeded() async {
		guard page == nil else { return }
		guard errorMessage == nil else { return }
		await load()
	}

	private func load() async {
		guard !isLoading else { return }
		isLoading = true
		defer { isLoading = false }

		errorMessage = nil
		do {
			let loaded = try await api.fetchTyfloswiatPage(id: summary.id)
			guard !Task.isCancelled else { return }
			page = loaded
		} catch {
			guard !Task.isCancelled else { return }
			errorMessage = "Nie udało się pobrać danych. Spróbuj ponownie."
		}
	}
}

private enum TyfloSwiatMagazineParsing {
	private static let issuePattern = try? NSRegularExpression(pattern: "(\\d{1,2})\\s*/\\s*(\\d{4})", options: [])
	private static let yearPattern = try? NSRegularExpression(pattern: "(19\\d{2}|20\\d{2})", options: [])
	private static let hrefPattern = try? NSRegularExpression(pattern: "href\\s*=\\s*['\\\"]([^'\\\"]+)['\\\"]", options: [.caseInsensitive])
	private static let pdfPattern = try? NSRegularExpression(pattern: "href\\s*=\\s*['\\\"]([^'\\\"]+\\.pdf[^'\\\"]*)['\\\"]", options: [.caseInsensitive])

	static func parseIssueNumberAndYear(from title: String) -> (number: Int?, year: Int?) {
		let range = NSRange(title.startIndex ..< title.endIndex, in: title)

		if let issuePattern, let match = issuePattern.firstMatch(in: title, options: [], range: range) {
			let numberRange = match.range(at: 1)
			let yearRange = match.range(at: 2)
			let number = Range(numberRange, in: title).flatMap { Int(title[$0]) }
			let year = Range(yearRange, in: title).flatMap { Int(title[$0]) }
			return (number: number, year: year)
		}

		if let yearPattern, let match = yearPattern.firstMatch(in: title, options: [], range: range) {
			let yearRange = match.range(at: 1)
			let year = Range(yearRange, in: title).flatMap { Int(title[$0]) }
			return (number: nil, year: year)
		}

		return (number: nil, year: nil)
	}

	static func extractFirstPDFURL(from html: String) -> URL? {
		guard let pdfPattern else { return nil }
		let range = NSRange(html.startIndex ..< html.endIndex, in: html)
		guard let match = pdfPattern.firstMatch(in: html, options: [], range: range),
		      let urlRange = Range(match.range(at: 1), in: html)
		else {
			return nil
		}
		return URL(string: normalizeLink(String(html[urlRange])))
	}

	static func orderedTableOfContents(children: [WPPostSummary], issueHTML: String) -> [WPPostSummary] {
		guard !children.isEmpty else { return [] }

		let orderedLinks = extractLinks(from: issueHTML)
			.map(normalizeLink)
			.filter { link in
				guard !link.lowercased().contains(".pdf") else { return false }
				return link.contains("tyfloswiat.pl/czasopismo/")
			}

		var byLink: [String: WPPostSummary] = [:]
		for child in children {
			byLink[normalizeLink(child.link)] = child
		}

		var seenIDs = Set<Int>()
		var ordered: [WPPostSummary] = []
		for link in orderedLinks {
			guard let item = byLink[link] else { continue }
			guard !seenIDs.contains(item.id) else { continue }
			seenIDs.insert(item.id)
			ordered.append(item)
		}

		let remaining = children
			.filter { !seenIDs.contains($0.id) }
			.sorted { lhs, rhs in
				if lhs.date != rhs.date { return lhs.date > rhs.date }
				return lhs.id > rhs.id
			}

		return ordered + remaining
	}

	private static func extractLinks(from html: String) -> [String] {
		guard let hrefPattern else { return [] }
		let range = NSRange(html.startIndex ..< html.endIndex, in: html)

		var results: [String] = []
		for match in hrefPattern.matches(in: html, options: [], range: range) {
			guard let urlRange = Range(match.range(at: 1), in: html) else { continue }
			results.append(String(html[urlRange]))
		}
		return results
	}

	private static func normalizeLink(_ value: String) -> String {
		let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
		if trimmed.hasPrefix("/") {
			return normalizeLink("https://tyfloswiat.pl\(trimmed)")
		}

		guard var components = URLComponents(string: trimmed) else {
			return trimmed
		}

		if components.scheme == "http" {
			components.scheme = "https"
		}

		var normalized = components.string ?? trimmed
		while normalized.hasSuffix("/") {
			normalized.removeLast()
		}
		return normalized
	}
}
