//
//  Podcast.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 24/10/2022.
//

import Foundation

struct Podcast: Codable, Identifiable {
	struct PodcastTitle: Codable {
		var rendered: String
		private static let plainTextCache: NSCache<NSString, NSString> = {
			let cache = NSCache<NSString, NSString>()
			cache.countLimit = 2000
			return cache
		}()

		var html: NSAttributedString {
			let data = Data(rendered.utf8)
			if let attrString = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) {
				return attrString
			}
			return NSAttributedString()
		}

		var plainText: String {
			if let cached = Self.plainTextCache.object(forKey: rendered as NSString) {
				return cached as String
			}

			let trimmedRendered = rendered.trimmingCharacters(in: .whitespacesAndNewlines)
			if !trimmedRendered.contains("<"), !trimmedRendered.contains("&") {
				Self.plainTextCache.setObject(trimmedRendered as NSString, forKey: rendered as NSString)
				return trimmedRendered
			}

			let data = Data(rendered.utf8)
			let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
				.documentType: NSAttributedString.DocumentType.html,
				.characterEncoding: String.Encoding.utf8.rawValue,
			]
			if let attrString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
				let string = attrString.string.trimmingCharacters(in: .whitespacesAndNewlines)
				if !string.isEmpty {
					Self.plainTextCache.setObject(string as NSString, forKey: rendered as NSString)
					return string
				}
			}
			Self.plainTextCache.setObject(trimmedRendered as NSString, forKey: rendered as NSString)
			return trimmedRendered
		}
	}

	var id: Int
	var date: String
	var title: PodcastTitle
	var excerpt: PodcastTitle
	var content: PodcastTitle
	var guid: PodcastTitle

	private static let dateParser: DateFormatter = {
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
		return formatter
	}()

	private static let dateOutputFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.locale = Locale.autoupdatingCurrent
		formatter.dateStyle = .medium
		formatter.timeStyle = .none
		return formatter
	}()

	private static let dateFormatterLock = NSLock()

	var formattedDate: String {
		Self.dateFormatterLock.lock()
		defer { Self.dateFormatterLock.unlock() }

		guard let parsed = Self.dateParser.date(from: date) else { return date }
		return Self.dateOutputFormatter.string(from: parsed)
	}
}
