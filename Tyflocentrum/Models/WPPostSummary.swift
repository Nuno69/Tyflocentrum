//
//  WPPostSummary.swift
//  Tyflocentrum
//

import Foundation

struct WPPostSummary: Codable, Identifiable {
	var id: Int
	var date: String
	var title: Podcast.PodcastTitle
	var excerpt: Podcast.PodcastTitle?
	var link: String

	var excerptOrEmpty: Podcast.PodcastTitle {
		excerpt ?? Podcast.PodcastTitle(rendered: "")
	}

	func asPodcastStub() -> Podcast {
		Podcast(
			id: id,
			date: date,
			title: title,
			excerpt: excerptOrEmpty,
			content: Podcast.PodcastTitle(rendered: ""),
			guid: Podcast.PodcastTitle(rendered: link)
		)
	}
}
