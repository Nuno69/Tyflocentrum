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

	@EnvironmentObject var api: TyfloAPI
	@EnvironmentObject private var favorites: FavoritesStore
	@State private var comments = [Comment]()

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

	private var isFavorite: Bool {
		favorites.isFavorite(favoriteItem)
	}

	private var favoriteIconName: String {
		isFavorite ? "star.fill" : "star"
	}

	private var favoriteAccessibilityLabel: String {
		isFavorite ? "Usuń z ulubionych" : "Dodaj do ulubionych"
	}

	private func announceIfVoiceOver(_ message: String) {
		guard UIAccessibility.isVoiceOverRunning else { return }
		UIAccessibility.post(notification: .announcement, argument: message)
	}

	private func toggleFavorite() {
		let willAdd = !favorites.isFavorite(favoriteItem)
		favorites.toggle(favoriteItem)
		announceIfVoiceOver(willAdd ? "Dodano do ulubionych." : "Usunięto z ulubionych.")
	}

	@ToolbarContentBuilder
	private var toolbarContent: some ToolbarContent {
		ToolbarItemGroup(placement: .navigationBarTrailing) {
			Button(action: toggleFavorite) {
				Image(systemName: favoriteIconName)
			}
			.accessibilityLabel(favoriteAccessibilityLabel)
			.accessibilityIdentifier("podcastDetail.favorite")

			ShareLink(
				"Udostępnij",
				item: podcast.guid.plainText,
				message: Text(
					"Posłuchaj audycji \(podcast.title.plainText) w serwisie Tyflopodcast!\nUdostępnione przy pomocy aplikacji Tyflocentrum"
				)
			)

			NavigationLink {
				MediaPlayerView(
					podcast: api.getListenableURL(for: podcast),
					title: podcast.title.plainText,
					subtitle: podcast.formattedDate,
					canBeLive: false,
					podcastPostID: podcast.id
				)
			} label: {
				Text("Słuchaj")
					.accessibilityLabel("Słuchaj audycji")
					.accessibilityHint("Otwiera odtwarzacz audycji.")
					.accessibilityIdentifier("podcastDetail.listen")
			}
		}
	}

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
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

				Text(podcast.content.plainText)
					.font(.body)
					.textSelection(.enabled)
					.accessibilityIdentifier("podcastDetail.content")

				Divider()

				Text(comments.isEmpty ? "Brak komentarzy" : "\(comments.count) komentarzy")
					.foregroundColor(.secondary)
					.accessibilityIdentifier("podcastDetail.commentsSummary")
			}
			.padding()
		}
		.navigationTitle(podcast.title.plainText)
		.navigationBarTitleDisplayMode(.inline)
		.task {
			comments = await api.getComments(for: podcast)
		}
		.toolbar { toolbarContent }
	}
}
