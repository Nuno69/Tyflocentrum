//
//  ShortPodcastView.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 25/10/2022.
//

import Foundation
import SwiftUI
import UIKit

struct ShortPodcastView: View {
	let podcast: Podcast
	var showsListenAction = true
	var onListen: (() -> Void)? = nil
	var leadingSystemImageName: String? = nil
	var accessibilityKindLabel: String? = nil
	var accessibilityIdentifierOverride: String? = nil
	var favoriteItem: FavoriteItem? = nil

	@EnvironmentObject private var favorites: FavoritesStore
	@EnvironmentObject private var settings: SettingsStore

	private func announceIfVoiceOver(_ message: String) {
		guard UIAccessibility.isVoiceOverRunning else { return }
		UIAccessibility.post(notification: .announcement, argument: message)
	}

	private func copyPodcastLink() {
		let urlString = podcast.guid.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !urlString.isEmpty else { return }
		UIPasteboard.general.string = urlString
		announceIfVoiceOver("Skopiowano link.")
	}

	private func toggleFavorite(_ item: FavoriteItem) {
		let willAdd = !favorites.isFavorite(item)
		favorites.toggle(item)
		announceIfVoiceOver(willAdd ? "Dodano do ulubionych." : "Usunięto z ulubionych.")
	}

	var body: some View {
		let title = podcast.title.plainText
		let refreshID = "\(accessibilityIdentifierOverride ?? "podcast.row.\(podcast.id)").\(settings.contentKindLabelPosition.rawValue)"
		let accessibilityTitle = {
			let kind = accessibilityKindLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
			guard !kind.isEmpty else { return title }

			switch settings.contentKindLabelPosition {
			case .before:
				return "\(kind). \(title)"
			case .after:
				return "\(title). \(kind)"
			}
		}()
		let favoriteTitle = favoriteItem.map { favorites.isFavorite($0) ? "Usuń z ulubionych" : "Dodaj do ulubionych" }
		let actionLabels = ([showsListenAction ? "Słuchaj" : nil, favoriteTitle, "Skopiuj link"] as [String?])
			.compactMap { $0 }
		let hint = "Dwukrotnie stuknij, aby otworzyć szczegóły. Akcje: \(actionLabels.joined(separator: ", "))."
		let rowContent = VStack(alignment: .leading, spacing: 6) {
			Text(title)
				.font(.headline)
				.foregroundColor(.primary)
				.multilineTextAlignment(.leading)

			Text(podcast.formattedDate)
				.font(.caption)
				.foregroundColor(.secondary)
		}
		let row = HStack(alignment: .top, spacing: 12) {
			if let leadingSystemImageName {
				Image(systemName: leadingSystemImageName)
					.font(.title3)
					.foregroundColor(.secondary)
					.accessibilityHidden(true)
			}

			rowContent
		}
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(accessibilityTitle)
		.accessibilityValue(podcast.formattedDate)
		.accessibilityHint(hint)
		.accessibilityIdentifier(accessibilityIdentifierOverride ?? "podcast.row.\(podcast.id)")
		.id(refreshID)

		Group {
			if showsListenAction {
				if let favoriteItem, let favoriteTitle {
					row
						.accessibilityAction(named: "Skopiuj link") {
							copyPodcastLink()
						}
						.accessibilityAction(named: favoriteTitle) {
							toggleFavorite(favoriteItem)
						}
						.accessibilityAction(named: "Słuchaj") {
							onListen?()
						}
						.contextMenu {
							Button(favoriteTitle) {
								toggleFavorite(favoriteItem)
							}
						}
				} else {
					row
						.accessibilityAction(named: "Skopiuj link") {
							copyPodcastLink()
						}
						.accessibilityAction(named: "Słuchaj") {
							onListen?()
						}
				}
			} else {
				if let favoriteItem, let favoriteTitle {
					row
						.accessibilityAction(named: "Skopiuj link") {
							copyPodcastLink()
						}
						.accessibilityAction(named: favoriteTitle) {
							toggleFavorite(favoriteItem)
						}
						.contextMenu {
							Button(favoriteTitle) {
								toggleFavorite(favoriteItem)
							}
						}
				} else {
					row
						.accessibilityAction(named: "Skopiuj link") {
							copyPodcastLink()
						}
				}
			}
		}
	}
}
