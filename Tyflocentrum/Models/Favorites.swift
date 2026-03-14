import Foundation

enum FavoriteKind: String, Codable, CaseIterable, Identifiable {
	case podcast
	case article
	case topic
	case link

	var id: String { rawValue }

	var title: String {
		switch self {
		case .podcast:
			return "Podcasty"
		case .article:
			return "Artykuły"
		case .topic:
			return "Tematy"
		case .link:
			return "Linki"
		}
	}
}

enum FavoritesFilter: String, CaseIterable, Identifiable {
	case all
	case podcasts
	case articles
	case topics
	case links

	var id: String { rawValue }

	var title: String {
		switch self {
		case .all:
			return "Wszystkie"
		case .podcasts:
			return "Podcasty"
		case .articles:
			return "Artykuły"
		case .topics:
			return "Tematy"
		case .links:
			return "Linki"
		}
	}

	var kind: FavoriteKind? {
		switch self {
		case .all:
			return nil
		case .podcasts:
			return .podcast
		case .articles:
			return .article
		case .topics:
			return .topic
		case .links:
			return .link
		}
	}
}

enum FavoriteArticleOrigin: String, Codable {
	case post
	case page
}

struct FavoriteTopic: Codable, Equatable, Identifiable {
	let podcastID: Int
	let podcastTitle: String
	let podcastSubtitle: String?
	let title: String
	let seconds: Double

	var id: String {
		let normalizedTitle = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
		return "topic.\(podcastID).\(Int(seconds)).\(normalizedTitle)"
	}
}

struct FavoriteLink: Codable, Equatable, Identifiable {
	let podcastID: Int
	let podcastTitle: String
	let podcastSubtitle: String?
	let title: String
	let urlString: String

	var id: String {
		"link.\(podcastID).\(urlString.lowercased())"
	}

	var url: URL? { URL(string: urlString) }
}

enum FavoriteItem: Identifiable, Codable, Equatable {
	case podcast(WPPostSummary)
	case article(summary: WPPostSummary, origin: FavoriteArticleOrigin)
	case topic(FavoriteTopic)
	case link(FavoriteLink)

	static func == (lhs: FavoriteItem, rhs: FavoriteItem) -> Bool {
		lhs.id == rhs.id
	}

	var id: String {
		switch self {
		case let .podcast(summary):
			return "podcast.\(summary.id)"
		case let .article(summary, origin):
			return "article.\(origin.rawValue).\(summary.id)"
		case let .topic(topic):
			return topic.id
		case let .link(link):
			return link.id
		}
	}

	var kind: FavoriteKind {
		switch self {
		case .podcast:
			return .podcast
		case .article:
			return .article
		case .topic:
			return .topic
		case .link:
			return .link
		}
	}

	var title: String {
		switch self {
		case let .podcast(summary):
			return summary.title.plainText
		case let .article(summary, _):
			return summary.title.plainText
		case let .topic(topic):
			return topic.title
		case let .link(link):
			return link.title
		}
	}

	var subtitle: String? {
		switch self {
		case let .podcast(summary):
			return summary.asPodcastStub().formattedDate
		case let .article(summary, _):
			return summary.asPodcastStub().formattedDate
		case let .topic(topic):
			return topic.podcastTitle
		case let .link(link):
			return link.podcastTitle
		}
	}

	private enum CodingKeys: String, CodingKey {
		case type
		case summary
		case origin
		case topic
		case link
	}

	private enum ItemType: String, Codable {
		case podcast
		case article
		case topic
		case link
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let type = try container.decode(ItemType.self, forKey: .type)
		switch type {
		case .podcast:
			let summary = try container.decode(WPPostSummary.self, forKey: .summary)
			self = .podcast(summary)
		case .article:
			let summary = try container.decode(WPPostSummary.self, forKey: .summary)
			let origin = try container.decode(FavoriteArticleOrigin.self, forKey: .origin)
			self = .article(summary: summary, origin: origin)
		case .topic:
			let topic = try container.decode(FavoriteTopic.self, forKey: .topic)
			self = .topic(topic)
		case .link:
			let link = try container.decode(FavoriteLink.self, forKey: .link)
			self = .link(link)
		}
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		switch self {
		case let .podcast(summary):
			try container.encode(ItemType.podcast, forKey: .type)
			try container.encode(summary, forKey: .summary)
		case let .article(summary, origin):
			try container.encode(ItemType.article, forKey: .type)
			try container.encode(summary, forKey: .summary)
			try container.encode(origin, forKey: .origin)
		case let .topic(topic):
			try container.encode(ItemType.topic, forKey: .type)
			try container.encode(topic, forKey: .topic)
		case let .link(link):
			try container.encode(ItemType.link, forKey: .type)
			try container.encode(link, forKey: .link)
		}
	}
}
