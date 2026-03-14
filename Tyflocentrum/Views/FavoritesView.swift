import SwiftUI
import UIKit

struct FavoritesView: View {
	@EnvironmentObject private var favorites: FavoritesStore

	@State private var filter: FavoritesFilter = .all
	@State private var playerPodcast: Podcast?

	private func announceIfVoiceOver(_ message: String) {
		guard UIAccessibility.isVoiceOverRunning else { return }
		UIAccessibility.post(notification: .announcement, argument: message)
	}

	private func removeFavorite(_ item: FavoriteItem) {
		favorites.remove(item)
		announceIfVoiceOver("Usunięto z ulubionych.")
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
							FavoriteTopicRow(topic: topic)
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

	@EnvironmentObject private var api: TyfloAPI
	@EnvironmentObject private var favorites: FavoritesStore
	@EnvironmentObject private var audioPlayer: AudioPlayer

	private func announceIfVoiceOver(_ message: String) {
		guard UIAccessibility.isVoiceOverRunning else { return }
		UIAccessibility.post(notification: .announcement, argument: message)
	}

	private func favoriteItem() -> FavoriteItem {
		.topic(topic)
	}

	private func toggleFavorite() {
		let item = favoriteItem()
		let willAdd = !favorites.isFavorite(item)
		favorites.toggle(item)
		announceIfVoiceOver(willAdd ? "Dodano do ulubionych." : "Usunięto z ulubionych.")
	}

	private func playFromMarker() {
		guard !ProcessInfo.processInfo.arguments.contains("UI_TESTING") else { return }
		let url = api.getListenableURL(for: Podcast(
			id: topic.podcastID,
			date: "",
			title: .init(rendered: topic.podcastTitle),
			excerpt: .init(rendered: ""),
			content: .init(rendered: ""),
			guid: .init(rendered: "https://tyflopodcast.net/?p=\(topic.podcastID)")
		))

		audioPlayer.play(
			url: url,
			title: topic.podcastTitle,
			subtitle: topic.podcastSubtitle,
			isLiveStream: false,
			seekTo: topic.seconds
		)
		announceIfVoiceOver("Odtwarzanie od \(Int(topic.seconds)) sekund.")
	}

	var body: some View {
		let item = favoriteItem()
		let isFavorite = favorites.isFavorite(item)

		NavigationLink {
			FavoriteTopicPlayerView(topic: topic)
		} label: {
			VStack(alignment: .leading, spacing: 4) {
				Text(topic.title)
					.foregroundColor(.primary)
				Text(topic.podcastTitle)
					.font(.caption)
					.foregroundColor(.secondary)
			}
		}
		.contextMenu {
			Button("Odtwarzaj od tego miejsca") {
				playFromMarker()
			}
			Button(isFavorite ? "Usuń z ulubionych" : "Dodaj do ulubionych") {
				toggleFavorite()
			}
		}
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(topic.title)
		.accessibilityValue(topic.podcastTitle)
		.accessibilityHint("Dwukrotnie stuknij, aby otworzyć odtwarzacz na tym fragmencie.")
		.accessibilityAction(named: "Odtwarzaj od tego miejsca") {
			playFromMarker()
		}
		.accessibilityAction(named: isFavorite ? "Usuń z ulubionych" : "Dodaj do ulubionych") {
			toggleFavorite()
		}
	}
}

private struct FavoriteTopicPlayerView: View {
	let topic: FavoriteTopic

	@EnvironmentObject private var api: TyfloAPI
	@EnvironmentObject private var audioPlayer: AudioPlayer

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
			podcastPostID: topic.podcastID
		)
		.onAppear {
			guard !ProcessInfo.processInfo.arguments.contains("UI_TESTING") else { return }
			audioPlayer.play(
				url: makePodcastURL(),
				title: topic.podcastTitle,
				subtitle: topic.podcastSubtitle,
				isLiveStream: false,
				seekTo: topic.seconds
			)
		}
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

	private func toggleFavorite() {
		let item = favoriteItem()
		let willAdd = !favorites.isFavorite(item)
		favorites.toggle(item)
		announceIfVoiceOver(willAdd ? "Dodano do ulubionych." : "Usunięto z ulubionych.")
	}

	var body: some View {
		let item = favoriteItem()
		let isFavorite = favorites.isFavorite(item)

		if let url = link.url {
			Button {
				openURL(url)
			} label: {
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
			.buttonStyle(.plain)
			.tint(.primary)
			.contextMenu {
				Button("Skopiuj link") {
					copyLink(url)
				}
				Button("Udostępnij link") {
					sharePayload = SharePayload(activityItems: [activityItem(for: url)])
				}
				Button(isFavorite ? "Usuń z ulubionych" : "Dodaj do ulubionych") {
					toggleFavorite()
				}
			}
			.accessibilityElement(children: .ignore)
			.accessibilityLabel(link.title)
			.accessibilityValue(hostLabel(for: url) ?? "")
			.accessibilityHint("Otwiera odnośnik.")
			.accessibilityAction(named: "Skopiuj link") {
				copyLink(url)
			}
			.accessibilityAction(named: "Udostępnij link") {
				sharePayload = SharePayload(activityItems: [activityItem(for: url)])
			}
			.accessibilityAction(named: isFavorite ? "Usuń z ulubionych" : "Dodaj do ulubionych") {
				toggleFavorite()
			}
			.sheet(item: $sharePayload) { payload in
				ActivityView(activityItems: payload.activityItems)
			}
		} else {
			Text(link.title)
				.foregroundColor(.secondary)
		}
	}
}
