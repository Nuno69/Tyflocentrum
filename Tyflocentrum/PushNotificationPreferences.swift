import Foundation

struct PushNotificationPreferences: Codable, Equatable {
	var podcast: Bool
	var article: Bool
	var live: Bool
	var schedule: Bool

	init(
		podcast: Bool = true,
		article: Bool = true,
		live: Bool = true,
		schedule: Bool = true
	) {
		self.podcast = podcast
		self.article = article
		self.live = live
		self.schedule = schedule
	}

	var allEnabled: Bool {
		podcast && article && live && schedule
	}

	mutating func setAll(_ enabled: Bool) {
		podcast = enabled
		article = enabled
		live = enabled
		schedule = enabled
	}

	enum CodingKeys: String, CodingKey {
		case podcast
		case article
		case live
		case schedule
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		podcast = try container.decodeIfPresent(Bool.self, forKey: .podcast) ?? true
		article = try container.decodeIfPresent(Bool.self, forKey: .article) ?? true
		live = try container.decodeIfPresent(Bool.self, forKey: .live) ?? true
		schedule = try container.decodeIfPresent(Bool.self, forKey: .schedule) ?? true
	}
}
