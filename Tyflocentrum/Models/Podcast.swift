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
		private static let fastHTMLPlainTextThresholdBytes: Int = 20000
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

			if trimmedRendered.utf8.count > Self.fastHTMLPlainTextThresholdBytes {
				let fastParsed = Self.fastHTMLToPlainText(trimmedRendered)
				if !fastParsed.isEmpty {
					Self.plainTextCache.setObject(fastParsed as NSString, forKey: rendered as NSString)
					return fastParsed
				}
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

		private static func fastHTMLToPlainText(_ html: String) -> String {
			var output = String()
			output.reserveCapacity(min(html.utf8.count, 256_000))

			var isInsideTag = false
			var isCollectingTagName = false
			var isClosingTag = false
			var tagName = String()
			tagName.reserveCapacity(16)

			func appendNewlineIfNeeded() {
				guard !output.hasSuffix("\n") else { return }
				output.append("\n")
			}

			func handleTagName(_ name: String, isClosing: Bool) {
				guard !name.isEmpty else { return }

				switch name {
				case "br":
					appendNewlineIfNeeded()
				case "p", "div", "li", "tr", "h1", "h2", "h3", "h4", "h5", "h6":
					// Add a newline for both opening and closing tags to keep long show notes readable.
					appendNewlineIfNeeded()
				default:
					if isClosing, name == "a" {
						// Keep link text readable by separating consecutive links.
						appendNewlineIfNeeded()
					}
				}
			}

			for scalar in html.unicodeScalars {
				if !isInsideTag {
					if scalar == "<" {
						isInsideTag = true
						isCollectingTagName = false
						isClosingTag = false
						tagName.removeAll(keepingCapacity: true)
						continue
					}
					output.unicodeScalars.append(scalar)
					continue
				}

				if scalar == ">" {
					isInsideTag = false
					handleTagName(tagName, isClosing: isClosingTag)
					continue
				}

				if tagName.isEmpty, !isCollectingTagName {
					if scalar == "/" {
						isClosingTag = true
						continue
					}
					if CharacterSet.whitespacesAndNewlines.contains(scalar) {
						continue
					}
					isCollectingTagName = true
				}

				guard isCollectingTagName else { continue }

				if CharacterSet.alphanumerics.contains(scalar) {
					let value = scalar.value
					if value >= 65, value <= 90, let lower = UnicodeScalar(value + 32) {
						tagName.unicodeScalars.append(lower)
					} else {
						tagName.unicodeScalars.append(scalar)
					}
				} else {
					isCollectingTagName = false
				}
			}

			if output.contains("&") {
				output = Self.decodeHTMLEntities(output)
			}

			output = output.replacingOccurrences(of: "\u{00A0}", with: " ")
			return output.trimmingCharacters(in: .whitespacesAndNewlines)
		}

		private static func decodeHTMLEntities(_ text: String) -> String {
			guard let firstAmpersand = text.firstIndex(of: "&") else { return text }

			var decoded = String()
			decoded.reserveCapacity(text.count)
			decoded.append(contentsOf: text[..<firstAmpersand])

			var index = firstAmpersand
			while index < text.endIndex {
				guard text[index] == "&" else {
					decoded.append(text[index])
					index = text.index(after: index)
					continue
				}

				guard let semicolon = text[index...].firstIndex(of: ";") else {
					decoded.append(text[index])
					index = text.index(after: index)
					continue
				}

				let entityStart = text.index(after: index)
				let entity = text[entityStart ..< semicolon]
				if let replacement = Self.decodeHTMLEntity(entity) {
					decoded.append(replacement)
					index = text.index(after: semicolon)
					continue
				}

				decoded.append(text[index])
				index = text.index(after: index)
			}

			return decoded
		}

		private static func decodeHTMLEntity(_ entity: Substring) -> String? {
			switch entity {
			case "amp":
				return "&"
			case "lt":
				return "<"
			case "gt":
				return ">"
			case "quot":
				return "\""
			case "apos":
				return "'"
			case "nbsp":
				return "\u{00A0}"
			default:
				if entity.hasPrefix("#x") || entity.hasPrefix("#X") {
					let hex = entity.dropFirst(2)
					guard let value = UInt32(hex, radix: 16), let scalar = UnicodeScalar(value) else { return nil }
					return String(scalar)
				}
				if entity.hasPrefix("#") {
					let digits = entity.dropFirst()
					guard let value = UInt32(digits), let scalar = UnicodeScalar(value) else { return nil }
					return String(scalar)
				}
				return nil
			}
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
