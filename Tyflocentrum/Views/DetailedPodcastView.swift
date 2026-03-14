//
//  DetailedPodcastView.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 27/10/2022.
//

import Foundation
import SwiftUI
import UIKit

struct DetailedPodcastView: View {
	let podcast: Podcast

	@EnvironmentObject private var api: TyfloAPI
	@EnvironmentObject private var favorites: FavoritesStore
	@EnvironmentObject private var diagnostics: DiagnosticsStore

	@State private var isFavorite = false
	@State private var plainTextContent: String?
	@State private var commentsCount: Int?
	@State private var isCommentsCountLoading = false
	@State private var commentsCountErrorMessage: String?
	@AccessibilityFocusState private var focusedElement: FocusedElement?

	private enum FocusedElement: Hashable {
		case favorite
		case commentsSummary
	}

	private var favoriteItem: FavoriteItem {
		let summary = WPPostSummary(
			id: podcast.id,
			date: podcast.date,
			title: podcast.title,
			excerpt: podcast.excerpt,
			link: podcast.guid.plainText
		)
		return .podcast(summary)
	}

	private func postLayoutChangedIfVoiceOver() {
		guard UIAccessibility.isVoiceOverRunning else { return }
		UIAccessibility.post(notification: .layoutChanged, argument: nil)
	}

	private func postScreenChangedIfVoiceOver() {
		guard UIAccessibility.isVoiceOverRunning else { return }
		UIAccessibility.post(notification: .screenChanged, argument: nil)
	}

	private func refreshVoiceOverFocus(_ element: FocusedElement) {
		guard UIAccessibility.isVoiceOverRunning else { return }
		Task { @MainActor in
			focusedElement = nil
			await Task.yield()
			focusedElement = element
		}
	}

	private var commentsCountValueText: String {
		if let errorMessage = commentsCountErrorMessage {
			return errorMessage
		}
		if isCommentsCountLoading, commentsCount == nil {
			return "Ładowanie…"
		}
		guard let count = commentsCount else {
			return "Ładowanie…"
		}
		let noun = PolishPluralization.nounForm(
			for: count,
			singular: "komentarz",
			few: "komentarze",
			many: "komentarzy"
		)
		return "\(count) \(noun)"
	}

	private var headerSection: some View {
		VStack(alignment: .leading, spacing: 6) {
			Text(podcast.title.plainText)
				.font(.title3.weight(.semibold))

			Text(podcast.formattedDate)
				.font(.subheadline)
				.foregroundColor(.secondary)
		}
		.accessibilityElement(children: .combine)
		.accessibilityAddTraits(.isHeader)
		.accessibilityIdentifier("podcastDetail.header")
	}

	private var actionsSection: some View {
		VStack(alignment: .leading, spacing: 12) {
			NavigationLink {
				MediaPlayerView(
					podcast: api.getListenableURL(for: podcast),
					title: podcast.title.plainText,
					subtitle: podcast.formattedDate,
					canBeLive: false,
					podcastPostID: podcast.id
				)
			} label: {
				Label("Słuchaj", systemImage: "play.circle.fill")
			}
			.accessibilityLabel("Słuchaj audycji")
			.accessibilityHint("Otwiera odtwarzacz audycji.")
			.accessibilityIdentifier("podcastDetail.listen")

			ShareLink(
				item: podcast.guid.plainText,
				subject: Text(podcast.title.plainText),
				message: Text(
					"Posłuchaj audycji \(podcast.title.plainText) w serwisie Tyflopodcast!\nUdostępnione przy pomocy aplikacji Tyflocentrum"
				)
			) {
				Label("Udostępnij", systemImage: "square.and.arrow.up")
			}
			.accessibilityIdentifier("podcastDetail.share")

			Button {
				toggleFavorite()
			} label: {
				Label(
					isFavorite ? "Usuń z ulubionych" : "Dodaj do ulubionych",
					systemImage: isFavorite ? "star.fill" : "star"
				)
			}
			.accessibilityLabel(isFavorite ? "Usuń z ulubionych" : "Dodaj do ulubionych")
			.accessibilityIdentifier("podcastDetail.favorite")
			.accessibilityFocused($focusedElement, equals: .favorite)
			.id(isFavorite)
		}
	}

	private var commentsSection: some View {
		NavigationLink {
			PodcastCommentsView(postID: podcast.id, postTitle: podcast.title.plainText)
		} label: {
			HStack(spacing: 8) {
				Text("Komentarze")
					.foregroundColor(.secondary)
				Spacer(minLength: 0)
				Text(commentsCountValueText)
					.foregroundColor(.secondary)
				Image(systemName: "chevron.right")
					.font(.caption.weight(.semibold))
					.foregroundColor(.secondary)
					.accessibilityHidden(true)
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.accessibilityLabel(commentsCountValueText)
		.accessibilityIdentifier("podcastDetail.commentsSummary")
		.accessibilityFocused($focusedElement, equals: .commentsSummary)
		.id(commentsCountValueText)
	}

	private var contentSection: some View {
		Group {
			if let plainTextContent {
				AccessibleTextView(
					text: plainTextContent,
					accessibilityIdentifier: "podcastDetail.content"
				)
				.frame(maxWidth: .infinity, alignment: .leading)
			} else {
				Text("Ładowanie…")
					.foregroundColor(.secondary)
					.accessibilityIdentifier("podcastDetail.content")
			}
		}
	}

	private func toggleFavorite() {
		let willAdd = !isFavorite
		if UIAccessibility.isVoiceOverRunning {
			AppLog.accessibility.debug(
				"podcastDetail.toggleFavorite start id=\(podcast.id, privacy: .public) willAdd=\(willAdd, privacy: .public)"
			)
		}
		diagnostics.log("podcastDetail.toggleFavorite start id=\(podcast.id) willAdd=\(willAdd)")
		favorites.toggle(favoriteItem)
		isFavorite = favorites.isFavorite(favoriteItem)
		if UIAccessibility.isVoiceOverRunning {
			AppLog.accessibility.debug(
				"podcastDetail.toggleFavorite done id=\(podcast.id, privacy: .public) isFavorite=\(isFavorite, privacy: .public) items=\(favorites.items.count, privacy: .public)"
			)
		}
		diagnostics.log("podcastDetail.toggleFavorite done id=\(podcast.id) isFavorite=\(isFavorite) items=\(favorites.items.count)")
		refreshVoiceOverFocus(.favorite)
		Task { @MainActor in
			await Task.yield()
			postLayoutChangedIfVoiceOver()
		}
	}

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				headerSection
				actionsSection
				commentsSection

				Divider()

				contentSection
			}
			.padding()
		}
		.navigationTitle(podcast.title.plainText)
		.navigationBarTitleDisplayMode(.inline)
		.onAppear {
			isFavorite = favorites.isFavorite(favoriteItem)
			if UIAccessibility.isVoiceOverRunning {
				AppLog.accessibility.debug(
					"podcastDetail.appear id=\(podcast.id, privacy: .public) isFavorite=\(isFavorite, privacy: .public)"
				)
			}
			diagnostics.log("podcastDetail.appear id=\(podcast.id) isFavorite=\(isFavorite)")
			postScreenChangedIfVoiceOver()
		}
		.task(id: podcast.id) { @MainActor in
			isFavorite = favorites.isFavorite(favoriteItem)
			plainTextContent = nil
			commentsCount = nil
			isCommentsCountLoading = false
			commentsCountErrorMessage = nil
			diagnostics.log("podcastDetail.task start id=\(podcast.id)")
			defer {
				diagnostics.log("podcastDetail.task end id=\(podcast.id) cancelled=\(Task.isCancelled)")
			}

			async let contentTask: Void = loadPlainTextContent()
			async let commentsTask: Void = loadCommentsCount()
			_ = await(contentTask, commentsTask)
		}
		.onChange(of: commentsCountValueText) { _ in
			postLayoutChangedIfVoiceOver()
			diagnostics.log("podcastDetail.commentsValueChanged id=\(podcast.id) value=\(commentsCountValueText)")
			guard focusedElement == .commentsSummary else { return }
			refreshVoiceOverFocus(.commentsSummary)
		}
		.onReceive(favorites.$items) { _ in
			isFavorite = favorites.isFavorite(favoriteItem)
			diagnostics.log("podcastDetail.favoritesChanged id=\(podcast.id) isFavorite=\(isFavorite) items=\(favorites.items.count)")
		}
	}

	private func loadPlainTextContent() async {
		let rendered = podcast.content.rendered
		diagnostics.log("podcastDetail.loadContent start id=\(podcast.id) renderedLength=\(rendered.count)")
		let text = await Task.detached(priority: .background) { Podcast.PodcastTitle(rendered: rendered).plainText }.value
		guard !Task.isCancelled else {
			diagnostics.log("podcastDetail.loadContent cancelled id=\(podcast.id)")
			return
		}
		await MainActor.run {
			plainTextContent = text
			diagnostics.log("podcastDetail.loadContent done id=\(podcast.id) length=\(text.count)")
		}
	}

	@MainActor
	private func loadCommentsCount() async {
		if UIAccessibility.isVoiceOverRunning {
			AppLog.accessibility.debug("podcastDetail.loadCommentsCount start id=\(podcast.id, privacy: .public)")
		}
		diagnostics.log("podcastDetail.loadCommentsCount start id=\(podcast.id)")
		isCommentsCountLoading = true
		commentsCountErrorMessage = nil
		defer { isCommentsCountLoading = false }

		let timeoutSeconds: TimeInterval = 15
		let maxAttempts = 2

		for attempt in 1 ... maxAttempts {
			do {
				let loaded = try await withTimeout(timeoutSeconds) {
					try await api.fetchCommentsCount(forPostID: podcast.id)
				}
				commentsCount = loaded
				if UIAccessibility.isVoiceOverRunning {
					AppLog.accessibility.debug(
						"podcastDetail.loadCommentsCount success id=\(podcast.id, privacy: .public) count=\(loaded, privacy: .public) attempt=\(attempt, privacy: .public)"
					)
				}
				diagnostics.log("podcastDetail.loadCommentsCount success id=\(podcast.id) count=\(loaded) attempt=\(attempt)")
				return
			} catch {
				if Task.isCancelled {
					diagnostics.log("podcastDetail.loadCommentsCount taskCancelled id=\(podcast.id) attempt=\(attempt)")
					return
				}
				if error is CancellationError {
					commentsCountErrorMessage = "Nie udało się pobrać komentarzy. Spróbuj ponownie."
					if UIAccessibility.isVoiceOverRunning {
						AppLog.accessibility.debug(
							"podcastDetail.loadCommentsCount cancelled id=\(podcast.id, privacy: .public) attempt=\(attempt, privacy: .public)"
						)
					}
					diagnostics.log("podcastDetail.loadCommentsCount cancelled id=\(podcast.id) attempt=\(attempt)")
					return
				}

				if attempt < maxAttempts {
					try? await Task.sleep(nanoseconds: 250_000_000)
					continue
				}

				if error is AsyncTimeoutError {
					commentsCountErrorMessage = "Ładowanie trwa zbyt długo. Spróbuj ponownie."
				} else {
					commentsCountErrorMessage = "Nie udało się pobrać komentarzy. Spróbuj ponownie."
				}
				if UIAccessibility.isVoiceOverRunning {
					AppLog.accessibility.debug(
						"podcastDetail.loadCommentsCount failure id=\(podcast.id, privacy: .public) isTimeout=\(error is AsyncTimeoutError, privacy: .public)"
					)
				}
				diagnostics.log("podcastDetail.loadCommentsCount failure id=\(podcast.id) isTimeout=\(error is AsyncTimeoutError)")
			}
		}
	}
}
