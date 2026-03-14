//
//  MediaPlayerView.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 19/11/2022.
//

import Foundation
import SwiftUI
import UIKit

struct MediaPlayerView: View {
	private static let timeFormatterHMS: DateComponentsFormatter = {
		let formatter = DateComponentsFormatter()
		formatter.allowedUnits = [.hour, .minute, .second]
		formatter.unitsStyle = .positional
		formatter.zeroFormattingBehavior = [.pad]
		return formatter
	}()

	private static let timeFormatterMS: DateComponentsFormatter = {
		let formatter = DateComponentsFormatter()
		formatter.allowedUnits = [.minute, .second]
		formatter.unitsStyle = .positional
		formatter.zeroFormattingBehavior = [.pad]
		return formatter
	}()

	@EnvironmentObject var api: TyfloAPI
	@EnvironmentObject var audioPlayer: AudioPlayer
	let podcast: URL
	let title: String
	let subtitle: String?
	let canBeLive: Bool
	let podcastPostID: Int?
	@State private var shouldNavigateToContact = false
	@State private var shouldShowNoLiveAlert = false
	@State private var isScrubbing = false
	@State private var scrubPosition: Double = 0
	@State private var didAutoStartPlayback = false

	@State private var isShowNotesLoading = false
	@State private var chapterMarkers: [ChapterMarker] = []
	@State private var relatedLinks: [RelatedLink] = []
	@State private var shouldShowChapterMarkers = false
	@State private var shouldShowRelatedLinks = false

	init(podcast: URL, title: String, subtitle: String?, canBeLive: Bool, podcastPostID: Int? = nil) {
		self.podcast = podcast
		self.title = title
		self.subtitle = subtitle
		self.canBeLive = canBeLive
		self.podcastPostID = podcastPostID
	}

	private func loadShowNotes() async {
		guard let podcastPostID else { return }
		guard !isShowNotesLoading else { return }

		isShowNotesLoading = true
		defer { isShowNotesLoading = false }

		let comments = await api.getComments(forPostID: podcastPostID)
		let parsed = ShowNotesParser.parse(from: comments)
		chapterMarkers = parsed.markers
		relatedLinks = parsed.links
	}

	func performLiveCheck() async {
		let (available, _) = await api.isTPAvailable()
		if available {
			shouldNavigateToContact = true
		} else {
			shouldShowNoLiveAlert = true
		}
	}

	private func announceIfVoiceOver(_ message: String) {
		guard UIAccessibility.isVoiceOverRunning else { return }
		UIAccessibility.post(notification: .announcement, argument: message)
	}

	private func announcePlaybackRate() {
		let newPlaybackRateText = PlaybackRatePolicy.formattedRate(audioPlayer.playbackRate)
		announceIfVoiceOver("Prędkość \(newPlaybackRateText)x")
	}

	private func announceSeek(delta: Double) {
		let seconds = Int(abs(delta))
		let fallback = delta < 0 ? "Cofnięto \(seconds) sekund." : "Przewinięto do przodu \(seconds) sekund."

		guard let duration = audioPlayer.duration, duration.isFinite, duration > 0 else {
			announceIfVoiceOver(fallback)
			return
		}

		let target = SeekPolicy.targetTime(elapsed: audioPlayer.elapsedTime, delta: delta) ?? audioPlayer.elapsedTime
		let positionText = formatTime(target)
		let durationText = formatTime(duration)
		announceIfVoiceOver("Pozycja \(positionText) z \(durationText).")
	}

	func togglePlayback() {
		let willPlay = audioPlayer.currentURL != podcast || !audioPlayer.isPlaying
		audioPlayer.togglePlayPause(url: podcast, title: title, subtitle: subtitle, isLiveStream: canBeLive)
		announceIfVoiceOver(willPlay ? "Odtwarzanie." : "Pauza.")
	}

	func formatTime(_ seconds: TimeInterval) -> String {
		guard seconds.isFinite, seconds >= 0 else { return "--:--" }
		let formatter = seconds >= 3600 ? Self.timeFormatterHMS : Self.timeFormatterMS
		return formatter.string(from: seconds) ?? "--:--"
	}

	var body: some View {
		let isLiveStream = canBeLive
		let isPlayingCurrentItem = audioPlayer.isPlaying && audioPlayer.currentURL == podcast
		let displayedTime = isScrubbing ? scrubPosition : audioPlayer.elapsedTime
		let playbackRateText = PlaybackRatePolicy.formattedRate(audioPlayer.playbackRate)
		VStack(spacing: 24) {
			VStack(spacing: 6) {
				Text(title)
					.font(.headline)
					.multilineTextAlignment(.center)

				if let subtitle, !subtitle.isEmpty {
					Text(subtitle)
						.font(.subheadline)
						.foregroundColor(.secondary)
						.multilineTextAlignment(.center)
				}
			}
			.accessibilityElement(children: .combine)
			.accessibilityAddTraits(.isHeader)

			HStack(alignment: .center, spacing: 24) {
				if !isLiveStream {
					Button {
						audioPlayer.skipBackward(seconds: 30)
						announceSeek(delta: -30)
					} label: {
						Image(systemName: "gobackward.30")
							.font(.title2)
							.imageScale(.large)
					}
					.accessibilityLabel("Cofnij 30 sekund")
					.accessibilityHint("Dwukrotnie stuknij, aby cofnąć o 30 sekund.")
					.accessibilityIdentifier("player.skipBackward30")
				}

				Button {
					togglePlayback()
				} label: {
					Image(systemName: isPlayingCurrentItem ? "pause.circle.fill" : "play.circle.fill")
						.font(.largeTitle)
						.imageScale(.large)
				}
				.accessibilityLabel(isPlayingCurrentItem ? "Pauza" : "Odtwarzaj")
				.accessibilityValue(isPlayingCurrentItem ? "Odtwarzanie trwa" : "Odtwarzanie wstrzymane")
				.accessibilityHint(isPlayingCurrentItem ? "Dwukrotnie stuknij, aby wstrzymać odtwarzanie." : "Dwukrotnie stuknij, aby rozpocząć odtwarzanie.")
				.accessibilityIdentifier("player.playPause")

				if !isLiveStream {
					Button {
						audioPlayer.skipForward(seconds: 30)
						announceSeek(delta: 30)
					} label: {
						Image(systemName: "goforward.30")
							.font(.title2)
							.imageScale(.large)
					}
					.accessibilityLabel("Przewiń do przodu 30 sekund")
					.accessibilityHint("Dwukrotnie stuknij, aby przewinąć do przodu o 30 sekund.")
					.accessibilityIdentifier("player.skipForward30")
				}
			}

			if !isLiveStream {
				VStack(spacing: 12) {
					if let duration = audioPlayer.duration, duration.isFinite, duration > 0 {
						HStack {
							Text(formatTime(displayedTime))
								.monospacedDigit()
								.foregroundColor(.secondary)
							Spacer()
							Text(formatTime(duration))
								.monospacedDigit()
								.foregroundColor(.secondary)
						}
						.accessibilityHidden(true)

						Slider(
							value: Binding(
								get: { displayedTime },
								set: { newValue in
									scrubPosition = newValue
								}
							),
							in: 0 ... duration,
							onEditingChanged: { editing in
								isScrubbing = editing
								if editing {
									scrubPosition = audioPlayer.elapsedTime
								} else {
									audioPlayer.seek(to: scrubPosition)
								}
							}
						)
						.accessibilityLabel("Pozycja odtwarzania")
						.accessibilityValue("\(formatTime(displayedTime)) z \(formatTime(duration))")
						.accessibilityHint("Przesuń w górę lub w dół jednym palcem, aby przewinąć.")
						.accessibilityIdentifier("player.position")
					} else {
						ProgressView()
							.accessibilityLabel("Ładowanie czasu trwania")
					}
				}
			}

			if !isLiveStream {
				Button {
					audioPlayer.cyclePlaybackRate()
					announcePlaybackRate()
				} label: {
					Text("Prędkość: \(playbackRateText)x")
				}
				.accessibilityLabel("Zmień prędkość odtwarzania")
				.accessibilityValue("\(playbackRateText)x")
				.accessibilityHint("Dwukrotnie stuknij, aby przełączyć prędkość. Przesuń w górę lub w dół, aby zwiększyć lub zmniejszyć.")
				.accessibilityIdentifier("player.speed")
				.accessibilityAdjustableAction { direction in
					switch direction {
					case .increment:
						audioPlayer.cyclePlaybackRate()
					case .decrement:
						audioPlayer.setPlaybackRate(PlaybackRatePolicy.previous(before: audioPlayer.playbackRate))
					@unknown default:
						break
					}
					announcePlaybackRate()
				}
			}

			if !isLiveStream {
				if isShowNotesLoading && (chapterMarkers.isEmpty && relatedLinks.isEmpty) {
					ProgressView("Ładowanie dodatków…")
						.accessibilityIdentifier("player.showNotesLoading")
				} else if !chapterMarkers.isEmpty || !relatedLinks.isEmpty {
					HStack(spacing: 12) {
						if !chapterMarkers.isEmpty {
							Button("Znaczniki czasu") {
								shouldShowChapterMarkers = true
							}
							.accessibilityHint("Wyświetla listę znaczników czasu. Dwukrotnie stuknij, aby przejść do wybranego fragmentu.")
							.accessibilityIdentifier("player.showChapterMarkers")
						}

						if !relatedLinks.isEmpty {
							Button("Odnośniki") {
								shouldShowRelatedLinks = true
							}
							.accessibilityHint("Wyświetla odnośniki uzupełniające audycję.")
							.accessibilityIdentifier("player.showRelatedLinks")
						}
					}
					.buttonStyle(.bordered)
				}
			}

			if canBeLive {
				Button("Skontaktuj się z Tyfloradiem") {
					Task {
						await performLiveCheck()
					}
				}
				.accessibilityHint("Sprawdza, czy trwa audycja interaktywna i otwiera formularz kontaktu.")
				.accessibilityIdentifier("player.contactRadio")
				.alert("Błąd", isPresented: $shouldShowNoLiveAlert) {
					Button("OK") {}
				} message: {
					Text("Na antenie Tyfloradia nie trwa teraz żadna audycja interaktywna.")
				}
			}

			Spacer()
		}
		.padding()
		.navigationTitle("Odtwarzacz")
		.onAppear {
			guard !ProcessInfo.processInfo.arguments.contains("UI_TESTING") else { return }
			guard !didAutoStartPlayback else { return }
			didAutoStartPlayback = true
			audioPlayer.play(url: podcast, title: title, subtitle: subtitle, isLiveStream: canBeLive)
		}
		.task(id: podcastPostID) {
			await loadShowNotes()
		}
		.background(
			NavigationLink(
				destination: Group {
					if let podcastPostID {
						ChapterMarkersView(
							podcastID: podcastPostID,
							podcastTitle: title,
							podcastSubtitle: subtitle,
							markers: chapterMarkers,
							formatTime: formatTime
						)
					} else {
						EmptyView()
					}
				},
				isActive: $shouldShowChapterMarkers
			) {
				EmptyView()
			}
			.hidden()
		)
		.background(
			NavigationLink(
				destination: Group {
					if let podcastPostID {
						RelatedLinksView(
							podcastID: podcastPostID,
							podcastTitle: title,
							podcastSubtitle: subtitle,
							links: relatedLinks
						)
					} else {
						EmptyView()
					}
				},
				isActive: $shouldShowRelatedLinks
			) {
				EmptyView()
			}
			.hidden()
		)
		.background(
			NavigationLink(destination: ContactView(), isActive: $shouldNavigateToContact) {
				EmptyView()
			}
			.hidden()
		)
		.accessibilityAction(.magicTap) {
			togglePlayback()
		}
	}
}

private struct ChapterMarkersView: View {
	let podcastID: Int
	let podcastTitle: String
	let podcastSubtitle: String?
	let markers: [ChapterMarker]
	let formatTime: (TimeInterval) -> String

	@EnvironmentObject private var audioPlayer: AudioPlayer
	@EnvironmentObject private var favorites: FavoritesStore
	@Environment(\.dismiss) private var dismiss

	private func announceIfVoiceOver(_ message: String) {
		guard UIAccessibility.isVoiceOverRunning else { return }
		UIAccessibility.post(notification: .announcement, argument: message)
	}

	private func favoriteItem(for marker: ChapterMarker) -> FavoriteItem {
		.topic(
			FavoriteTopic(
				podcastID: podcastID,
				podcastTitle: podcastTitle,
				podcastSubtitle: podcastSubtitle,
				title: marker.title,
				seconds: marker.seconds
			)
		)
	}

	private func toggleFavorite(_ item: FavoriteItem) {
		let willAdd = !favorites.isFavorite(item)
		favorites.toggle(item)
		announceIfVoiceOver(willAdd ? "Dodano do ulubionych." : "Usunięto z ulubionych.")
	}

	var body: some View {
		List(markers) { marker in
			let item = favoriteItem(for: marker)
			Button {
				audioPlayer.seek(to: marker.seconds)
				if !audioPlayer.isPlaying {
					audioPlayer.resume()
				}
				announceIfVoiceOver("Przejdź do \(marker.title), \(formatTime(marker.seconds)).")
				dismiss()
			} label: {
				HStack(alignment: .firstTextBaseline) {
					Text(marker.title)
					Spacer()
					Text(formatTime(marker.seconds))
						.monospacedDigit()
						.foregroundColor(.secondary)
				}
			}
			.accessibilityLabel(marker.title)
			.accessibilityValue(formatTime(marker.seconds))
			.accessibilityHint("Dwukrotnie stuknij, aby przewinąć do tego momentu.")
			.accessibilityAction(named: favorites.isFavorite(item) ? "Usuń z ulubionych" : "Dodaj do ulubionych") {
				toggleFavorite(item)
			}
			.contextMenu {
				Button(favorites.isFavorite(item) ? "Usuń z ulubionych" : "Dodaj do ulubionych") {
					toggleFavorite(item)
				}
			}
		}
		.navigationTitle("Znaczniki czasu")
		.navigationBarTitleDisplayMode(.inline)
	}
}

private struct RelatedLinksView: View {
	let podcastID: Int
	let podcastTitle: String
	let podcastSubtitle: String?
	let links: [RelatedLink]

	@Environment(\.openURL) private var openURL
	@EnvironmentObject private var favorites: FavoritesStore
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

	private func copyLink(_ link: RelatedLink) {
		UIPasteboard.general.string = copyableString(for: link.url)
		announceIfVoiceOver("Skopiowano link.")
	}

	private func activityItem(for url: URL) -> Any {
		if url.scheme?.lowercased() == "mailto" {
			return copyableString(for: url)
		}
		return url
	}

	private func favoriteItem(for link: RelatedLink) -> FavoriteItem {
		.link(
			FavoriteLink(
				podcastID: podcastID,
				podcastTitle: podcastTitle,
				podcastSubtitle: podcastSubtitle,
				title: link.title,
				urlString: link.url.absoluteString
			)
		)
	}

	private func toggleFavorite(_ item: FavoriteItem) {
		let willAdd = !favorites.isFavorite(item)
		favorites.toggle(item)
		announceIfVoiceOver(willAdd ? "Dodano do ulubionych." : "Usunięto z ulubionych.")
	}

	var body: some View {
		List(links) { link in
			let item = favoriteItem(for: link)
			Button {
				openURL(link.url)
			} label: {
				VStack(alignment: .leading, spacing: 4) {
					Text(link.title)
						.foregroundColor(.primary)

					if let host = hostLabel(for: link.url) {
						Text(host)
							.font(.caption)
							.foregroundColor(.secondary)
					}
				}
			}
			.buttonStyle(.plain)
			.tint(.primary)
			.contextMenu {
				Button("Skopiuj link") {
					copyLink(link)
				}
				Button("Udostępnij link") {
					sharePayload = SharePayload(activityItems: [activityItem(for: link.url)])
				}
				Button(favorites.isFavorite(item) ? "Usuń z ulubionych" : "Dodaj do ulubionych") {
					toggleFavorite(item)
				}
			}
			.accessibilityElement(children: .ignore)
			.accessibilityLabel(link.title)
			.accessibilityValue(hostLabel(for: link.url) ?? "")
			.accessibilityAddTraits(.isLink)
			.accessibilityRemoveTraits(.isButton)
			.accessibilityHint("Otwiera odnośnik.")
			.accessibilityAction(named: "Skopiuj link") {
				copyLink(link)
			}
			.accessibilityAction(named: "Udostępnij link") {
				sharePayload = SharePayload(activityItems: [activityItem(for: link.url)])
			}
			.accessibilityAction(named: favorites.isFavorite(item) ? "Usuń z ulubionych" : "Dodaj do ulubionych") {
				toggleFavorite(item)
			}
		}
		.navigationTitle("Odnośniki")
		.navigationBarTitleDisplayMode(.inline)
		.sheet(item: $sharePayload) { payload in
			ActivityView(activityItems: payload.activityItems)
		}
	}
}

struct SharePayload: Identifiable {
	let id = UUID()
	let activityItems: [Any]
}

struct ActivityView: UIViewControllerRepresentable {
	let activityItems: [Any]

	func makeUIViewController(context _: Context) -> UIActivityViewController {
		UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
	}

	func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}
