import SwiftUI
import UIKit

struct FavoritesView: View {
	@EnvironmentObject private var favorites: FavoritesStore

	@State private var filter: FavoritesFilter = .all
	@State private var playerPodcast: Podcast?
	@State private var selectedTopic: FavoriteTopic?

	private func announceIfVoiceOver(_ message: String) {
		guard UIAccessibility.isVoiceOverRunning else { return }
		UIAccessibility.post(notification: .announcement, argument: message)
	}

	private func removeFavorite(_ item: FavoriteItem) {
		favorites.remove(item)
	}

	var body: some View {
		let visibleItems = favorites.filtered(filter)

		List {
			Section {
				Picker("Filtr ulubionych", selection: $filter) {
					ForEach(FavoritesFilter.allCases) { item in
						Text(item.title)
							.tag(item)
					}
				}
				.pickerStyle(.segmented)
				.accessibilityIdentifier("favorites.filter")
			}

			if visibleItems.isEmpty {
				Section {
					Text("Brak ulubionych.")
						.foregroundColor(.secondary)
				}
			} else {
				Section {
					ForEach(visibleItems) { item in
						switch item {
						case let .podcast(summary):
							FavoritePodcastRow(
								summary: summary,
								onListen: { playerPodcast = summary.asPodcastStub() }
							)
						case let .article(summary, origin):
							FavoriteArticleRow(summary: summary, origin: origin)
						case let .topic(topic):
							FavoriteTopicRow(topic: topic) { selectedTopic = $0 }
						case let .link(link):
							FavoriteLinkRow(link: link)
						}
					}
				}
			}
		}
		.accessibilityIdentifier("favorites.list")
		.navigationTitle("Ulubione")
		.navigationBarTitleDisplayMode(.inline)
		.navigationDestination(item: $playerPodcast) { podcast in
			PodcastPlayerView(podcast: podcast)
		}
		.navigationDestination(item: $selectedTopic) { topic in
			FavoriteTopicPlayerView(topic: topic)
		}
	}
}

private struct FavoritePodcastRow: View {
	let summary: WPPostSummary
	let onListen: () -> Void

	var body: some View {
		let stubPodcast = summary.asPodcastStub()
		NavigationLink {
			LazyDetailedPodcastView(summary: summary)
		} label: {
			ShortPodcastView(
				podcast: stubPodcast,
				showsListenAction: true,
				onListen: onListen,
				leadingSystemImageName: "mic.fill",
				accessibilityKindLabel: "Podcast",
				favoriteItem: .podcast(summary)
			)
		}
		.accessibilityRemoveTraits(.isButton)
	}
}

private struct FavoriteArticleRow: View {
	let summary: WPPostSummary
	let origin: FavoriteArticleOrigin

	var body: some View {
		NavigationLink {
			switch origin {
			case .post:
				LazyDetailedArticleView(summary: summary)
			case .page:
				LazyDetailedTyfloswiatPageView(summary: summary)
			}
		} label: {
			ShortPodcastView(
				podcast: summary.asPodcastStub(),
				showsListenAction: false,
				leadingSystemImageName: "doc.text.fill",
				accessibilityKindLabel: "Artykuł",
				accessibilityIdentifierOverride: "article.row.\(summary.id)",
				favoriteItem: .article(summary: summary, origin: origin)
			)
		}
		.accessibilityRemoveTraits(.isButton)
	}
}

private struct FavoriteTopicRow: View {
	let topic: FavoriteTopic
	let onOpen: (FavoriteTopic) -> Void

	@EnvironmentObject private var favorites: FavoritesStore

	private func announceIfVoiceOver(_ message: String) {
		guard UIAccessibility.isVoiceOverRunning else { return }
		UIAccessibility.post(notification: .announcement, argument: message)
	}

	private var favoriteItem: FavoriteItem {
		.topic(topic)
	}

	private var isFavorite: Bool {
		favorites.isFavorite(favoriteItem)
	}

	private var favoriteActionTitle: String {
		isFavorite ? "Usuń z ulubionych" : "Dodaj do ulubionych"
	}

	private func toggleFavorite() {
		favorites.toggle(favoriteItem)
	}

	private func openPlayer() {
		onOpen(topic)
	}

	private var labelContent: some View {
		VStack(alignment: .leading, spacing: 4) {
			Text(topic.title)
				.foregroundColor(.primary)
			Text(topic.podcastTitle)
				.font(.caption)
				.foregroundColor(.secondary)
		}
	}

	@ViewBuilder
	private var contextMenuActions: some View {
		Button("Odtwarzaj od tego miejsca") {
			openPlayer()
		}
		Button(favoriteActionTitle) {
			toggleFavorite()
		}
	}

	var body: some View {
		NavigationLink {
			FavoriteTopicPlayerView(topic: topic)
		} label: {
			labelContent
		}
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(topic.title)
		.accessibilityValue(topic.podcastTitle)
		.accessibilityHint("Dwukrotnie stuknij, aby otworzyć odtwarzacz na tym fragmencie.")
		.accessibilityAction(named: "Odtwarzaj od tego miejsca") {
			openPlayer()
		}
		.accessibilityAction(named: favoriteActionTitle) {
			toggleFavorite()
		}
		.accessibilityIdentifier("favorites.topic.\(topic.podcastID).\(Int(topic.seconds))")
		.contextMenu {
			contextMenuActions
		}
	}
}

private struct FavoriteTopicPlayerView: View {
	let topic: FavoriteTopic

	@EnvironmentObject private var api: TyfloAPI

	private func makePodcastURL() -> URL {
		let stub = Podcast(
			id: topic.podcastID,
			date: "",
			title: .init(rendered: topic.podcastTitle),
			excerpt: .init(rendered: ""),
			content: .init(rendered: ""),
			guid: .init(rendered: "https://tyflopodcast.net/?p=\(topic.podcastID)")
		)
		return api.getListenableURL(for: stub)
	}

	var body: some View {
		MediaPlayerView(
			podcast: makePodcastURL(),
			title: topic.podcastTitle,
			subtitle: topic.podcastSubtitle,
			canBeLive: false,
			podcastPostID: topic.podcastID,
			initialSeekTo: topic.seconds
		)
	}
}

private struct FavoriteLinkRow: View {
	let link: FavoriteLink

	@EnvironmentObject private var favorites: FavoritesStore
	@Environment(\.openURL) private var openURL
	@State private var sharePayload: SharePayload?

	private func hostLabel(for url: URL) -> String? {
		if let host = url.host, !host.isEmpty {
			return host
		}
		if url.scheme?.lowercased() == "mailto" {
			return "e-mail"
		}
		return nil
	}

	private func announceIfVoiceOver(_ message: String) {
		guard UIAccessibility.isVoiceOverRunning else { return }
		UIAccessibility.post(notification: .announcement, argument: message)
	}

	private func copyableString(for url: URL) -> String {
		if url.scheme?.lowercased() == "mailto" {
			return url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
		}
		return url.absoluteString
	}

	private func copyLink(_ url: URL) {
		UIPasteboard.general.string = copyableString(for: url)
		announceIfVoiceOver("Skopiowano link.")
	}

	private func activityItem(for url: URL) -> Any {
		if url.scheme?.lowercased() == "mailto" {
			return copyableString(for: url)
		}
		return url
	}

	private func favoriteItem() -> FavoriteItem {
		.link(link)
	}

	private func favoriteActionTitle(isFavorite: Bool) -> String {
		isFavorite ? "Usuń z ulubionych" : "Dodaj do ulubionych"
	}

	private func toggleFavorite() {
		let item = favoriteItem()
		favorites.toggle(item)
	}

	private func shareLink(_ url: URL) {
		sharePayload = SharePayload(activityItems: [activityItem(for: url)])
	}

	private func linkLabel(for url: URL) -> some View {
		VStack(alignment: .leading, spacing: 4) {
			Text(link.title)
				.foregroundColor(.primary)
			if let host = hostLabel(for: url) {
				Text(host)
					.font(.caption)
					.foregroundColor(.secondary)
			}
			Text(link.podcastTitle)
				.font(.caption2)
				.foregroundColor(.secondary)
		}
	}

	@ViewBuilder
	private func contextMenuActions(for url: URL, isFavorite: Bool) -> some View {
		Button("Skopiuj link") {
			copyLink(url)
		}
		Button("Udostępnij link") {
			shareLink(url)
		}
		Button(favoriteActionTitle(isFavorite: isFavorite)) {
			toggleFavorite()
		}
	}

	private func unavailableLinkLabel() -> some View {
		Text(link.title)
			.foregroundColor(.secondary)
	}

	private func linkButton(for url: URL, isFavorite: Bool) -> some View {
		Button {
			openURL(url)
		} label: {
			linkLabel(for: url)
		}
		.buttonStyle(.plain)
		.tint(.primary)
		.contextMenu {
			contextMenuActions(for: url, isFavorite: isFavorite)
		}
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(link.title)
		.accessibilityValue(hostLabel(for: url) ?? "")
		.accessibilityHint("Otwiera odnośnik.")
		.accessibilityAction(named: "Skopiuj link") {
			copyLink(url)
		}
		.accessibilityAction(named: "Udostępnij link") {
			shareLink(url)
		}
		.accessibilityAction(named: favoriteActionTitle(isFavorite: isFavorite)) {
			toggleFavorite()
		}
	}

	var body: some View {
		let item = favoriteItem()
		let isFavorite = favorites.isFavorite(item)

		Group {
			if let url = link.url {
				linkButton(for: url, isFavorite: isFavorite)
			} else {
				unavailableLinkLabel()
			}
		}
		.sheet(item: $sharePayload) { payload in
			ActivityView(activityItems: payload.activityItems)
		}
	}
}
