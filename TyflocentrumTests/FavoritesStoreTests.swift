import Foundation
import XCTest

@testable import Tyflocentrum

@MainActor
final class FavoritesStoreTests: XCTestCase {
	private func makeDefaults() -> UserDefaults {
		let suite = "TyflocentrumTests.Favorites.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suite)!
		defaults.removePersistentDomain(forName: suite)
		return defaults
	}

	private func makeSummary(id: Int, date: String = "2026-01-20T00:59:40", title: String = "Test", link: String = "https://example.com") -> WPPostSummary {
		WPPostSummary(
			id: id,
			date: date,
			title: Podcast.PodcastTitle(rendered: title),
			excerpt: Podcast.PodcastTitle(rendered: "Excerpt"),
			link: link
		)
	}

	func testAddRemoveAndPersistence() async {
		let defaults = makeDefaults()

		let store = FavoritesStore(userDefaults: defaults, storageKey: "favorites.test")
		XCTAssertTrue(store.items.isEmpty)

		let podcast = FavoriteItem.podcast(makeSummary(id: 1, title: "P1", link: "https://tyflopodcast.net/?p=1"))
		let articlePost = FavoriteItem.article(summary: makeSummary(id: 2, title: "A1", link: "https://tyfloswiat.pl/?p=2"), origin: .post)
		let articlePage = FavoriteItem.article(summary: makeSummary(id: 3, title: "Page", link: "https://tyfloswiat.pl/?page_id=3"), origin: .page)
		let topic = FavoriteItem.topic(
			FavoriteTopic(
				podcastID: 1,
				podcastTitle: "P1",
				podcastSubtitle: "20 sty 2026",
				title: "Intro",
				seconds: 0
			)
		)
		let link = FavoriteItem.link(
			FavoriteLink(
				podcastID: 1,
				podcastTitle: "P1",
				podcastSubtitle: "20 sty 2026",
				title: "Strona",
				urlString: "https://example.com"
			)
		)

		store.add(podcast)
		store.add(articlePost)
		store.add(articlePage)
		store.add(topic)
		store.add(link)

		XCTAssertEqual(store.items.count, 5)
		XCTAssertTrue(store.isFavorite(podcast))
		XCTAssertTrue(store.isFavorite(articlePost))
		XCTAssertTrue(store.isFavorite(topic))
		XCTAssertTrue(store.isFavorite(link))

		store.remove(articlePage)
		XCTAssertFalse(store.isFavorite(articlePage))
		XCTAssertEqual(store.items.count, 4)

		// New store should load persisted state.
		let store2 = FavoritesStore(userDefaults: defaults, storageKey: "favorites.test")
		XCTAssertEqual(store2.items.count, 4)
		XCTAssertTrue(store2.isFavorite(podcast))
		XCTAssertFalse(store2.isFavorite(articlePage))
	}

	func testFilterReturnsOnlyMatchingKinds() async {
		let defaults = makeDefaults()
		let store = FavoritesStore(userDefaults: defaults, storageKey: "favorites.test")

		store.add(.podcast(makeSummary(id: 1)))
		store.add(.article(summary: makeSummary(id: 2), origin: .post))
		store.add(.topic(FavoriteTopic(podcastID: 1, podcastTitle: "P1", podcastSubtitle: nil, title: "Intro", seconds: 0)))
		store.add(.link(FavoriteLink(podcastID: 1, podcastTitle: "P1", podcastSubtitle: nil, title: "Link", urlString: "https://example.com")))

		XCTAssertEqual(store.filtered(.all).count, 4)
		XCTAssertEqual(store.filtered(.podcasts).count, 1)
		XCTAssertEqual(store.filtered(.articles).count, 1)
		XCTAssertEqual(store.filtered(.topics).count, 1)
		XCTAssertEqual(store.filtered(.links).count, 1)
	}
}
