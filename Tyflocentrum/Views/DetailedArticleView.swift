//
//  DetailedArticleView.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 13/11/2022.
//

import Foundation
import SwiftUI
import UIKit

struct DetailedArticleView: View {
	let article: Podcast
	let favoriteOrigin: FavoriteArticleOrigin
	@EnvironmentObject private var favorites: FavoritesStore

	init(article: Podcast, favoriteOrigin: FavoriteArticleOrigin = .post) {
		self.article = article
		self.favoriteOrigin = favoriteOrigin
	}

	private var favoriteItem: FavoriteItem {
		let summary = WPPostSummary(
			id: article.id,
			date: article.date,
			title: article.title,
			excerpt: article.excerpt,
			link: article.guid.plainText
		)
		return .article(summary: summary, origin: favoriteOrigin)
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

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			VStack(alignment: .leading, spacing: 6) {
				Text(article.title.plainText)
					.font(.title3.weight(.semibold))

				Text(article.formattedDate)
					.font(.subheadline)
					.foregroundColor(.secondary)
			}
			.accessibilityElement(children: .combine)
			.accessibilityAddTraits(.isHeader)
			.accessibilityIdentifier("articleDetail.header")
			.padding([.horizontal, .top])

			SafeHTMLView(
				htmlBody: article.content.rendered,
				baseURL: URL(string: "https://tyfloswiat.pl"),
				accessibilityIdentifier: "articleDetail.content"
			)
			.frame(maxWidth: .infinity, maxHeight: .infinity)
		}
		.navigationTitle(article.title.plainText)
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			ToolbarItem(placement: .navigationBarTrailing) {
				Button {
					toggleFavorite()
				} label: {
					Image(systemName: favorites.isFavorite(favoriteItem) ? "star.fill" : "star")
				}
				.accessibilityLabel(favorites.isFavorite(favoriteItem) ? "Usuń z ulubionych" : "Dodaj do ulubionych")
				.accessibilityIdentifier("articleDetail.favorite")
			}
		}
	}
}
