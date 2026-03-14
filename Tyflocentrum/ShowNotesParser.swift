import Foundation

struct ChapterMarker: Identifiable, Equatable {
	let title: String
	let seconds: TimeInterval

	var id: String {
		"\(Int(seconds))-\(title)"
	}
}

struct RelatedLink: Identifiable, Equatable {
	let title: String
	let url: URL

	var id: String {
		"\(title)-\(url.absoluteString)"
	}
}

enum ShowNotesParser {
	private static let timecodeRegex: NSRegularExpression = {
		let pattern = #"(?:\b\d{1,2}:\d{2}:\d{2}\b|\b\d{1,2}:\d{2}\b)$"#
		return try! NSRegularExpression(pattern: pattern)
	}()

	private static let emailRegex: NSRegularExpression = {
		let pattern = #"[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}"#
		return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
	}()

	static func parse(from comments: [Comment]) -> (markers: [ChapterMarker], links: [RelatedLink]) {
		var markers: [ChapterMarker] = []
		var links: [RelatedLink] = []

		for comment in comments {
			let lines = normalizedLines(fromHTML: comment.content.rendered)

			if let parsedMarkers = parseMarkers(in: lines) {
				markers.append(contentsOf: parsedMarkers)
			}

			if let parsedLinks = parseLinks(in: lines) {
				links.append(contentsOf: parsedLinks)
			}
		}

		markers = uniqueMarkers(markers).sorted(by: { $0.seconds < $1.seconds })
		links = uniqueLinks(links)

		return (markers, links)
	}

	private static func uniqueMarkers(_ markers: [ChapterMarker]) -> [ChapterMarker] {
		var seen = Set<String>()
		var unique: [ChapterMarker] = []

		for marker in markers {
			let key = "\(Int(marker.seconds))|\(marker.title.lowercased())"
			guard !seen.contains(key) else { continue }
			seen.insert(key)
			unique.append(marker)
		}

		return unique
	}

	private static func uniqueLinks(_ links: [RelatedLink]) -> [RelatedLink] {
		var seen = Set<String>()
		var unique: [RelatedLink] = []

		for link in links {
			let key = "\(link.title.lowercased())|\(link.url.absoluteString.lowercased())"
			guard !seen.contains(key) else { continue }
			seen.insert(key)
			unique.append(link)
		}

		return unique
	}

	private static func normalizedLines(fromHTML html: String) -> [String] {
		let plainText = htmlToPlainText(html)
		return plainText
			.split(whereSeparator: { $0.isNewline })
			.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
			.filter { !$0.isEmpty }
	}

	private static func htmlToPlainText(_ html: String) -> String {
		let data = Data(html.utf8)
		let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
			.documentType: NSAttributedString.DocumentType.html,
			.characterEncoding: String.Encoding.utf8.rawValue,
		]
		if let attrString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
			return attrString.string
		}
		return html
	}

	private static func parseMarkers(in lines: [String]) -> [ChapterMarker]? {
		guard let headerIndex = lines.firstIndex(where: isMarkersHeader) else { return nil }

		var markers: [ChapterMarker] = []
		for line in lines[(headerIndex + 1)...] {
			guard let (title, seconds) = parseMarkerLine(line) else { continue }
			markers.append(ChapterMarker(title: title, seconds: seconds))
		}

		return markers.isEmpty ? nil : markers
	}

	private static func isMarkersHeader(_ line: String) -> Bool {
		let normalized = line.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
		return normalized.hasPrefix("znaczniki czasu") || normalized.hasPrefix("znaczniki czasowe")
			|| normalized.hasPrefix("znaczniki czasu:") || normalized.hasPrefix("znaczniki czasowe:")
	}

	private static func parseMarkerLine(_ line: String) -> (String, TimeInterval)? {
		let nsLine = line as NSString
		let range = NSRange(location: 0, length: nsLine.length)
		guard let match = timecodeRegex.firstMatch(in: line, range: range) else { return nil }

		let timeString = nsLine.substring(with: match.range)
		guard let seconds = parseTimecode(timeString) else { return nil }

		let titlePart = nsLine.substring(to: match.range.location)
		let title = titlePart
			.trimmingCharacters(in: .whitespacesAndNewlines)
			.trimmingCharacters(in: CharacterSet(charactersIn: "–—-:"))
			.trimmingCharacters(in: .whitespacesAndNewlines)

		guard !title.isEmpty else { return nil }
		return (title, seconds)
	}

	private static func parseTimecode(_ time: String) -> TimeInterval? {
		let parts = time.split(separator: ":")
		guard parts.count == 2 || parts.count == 3 else { return nil }

		let numbers = parts.compactMap { Int($0) }
		guard numbers.count == parts.count else { return nil }

		if numbers.count == 3 {
			return TimeInterval(numbers[0] * 3600 + numbers[1] * 60 + numbers[2])
		}
		return TimeInterval(numbers[0] * 60 + numbers[1])
	}

	private static func parseLinks(in lines: [String]) -> [RelatedLink]? {
		guard let headerIndex = lines.firstIndex(where: isLinksHeader) else { return nil }

		var links: [RelatedLink] = []
		var currentTitle: String?
		var currentURLs: [URL] = []

		func flushCurrent() {
			guard let currentTitle, !currentTitle.isEmpty else {
				currentURLs.removeAll(keepingCapacity: true)
				return
			}
			let urls = dedupURLs(currentURLs)
			guard !urls.isEmpty else { return }

			for url in urls {
				let title = makeLinkTitle(baseTitle: currentTitle, url: url, isDisambiguationNeeded: urls.count > 1)
				links.append(RelatedLink(title: title, url: url))
			}

			currentURLs.removeAll(keepingCapacity: true)
		}

		for line in lines[(headerIndex + 1)...] {
			if let bullet = parseBulletTitle(line) {
				flushCurrent()

				currentTitle = bullet.title
				currentURLs = bullet.urls
				continue
			}

			let foundURLs = extractURLs(from: line)
			if !foundURLs.isEmpty {
				currentURLs.append(contentsOf: foundURLs)
				continue
			}

			if let mail = parseEmailURL(from: line) {
				flushCurrent()
				let label = parseLeadingLabel(from: line) ?? "E-mail"
				links.append(RelatedLink(title: label, url: mail))
			}
		}

		flushCurrent()

		return links.isEmpty ? nil : links
	}

	private static func isLinksHeader(_ line: String) -> Bool {
		let normalized = line.lowercased()
		return normalized.contains("odnośnik") || normalized.contains("odnosnik")
			|| normalized.contains("linki") || normalized.contains("odnośniki")
	}

	private static func parseBulletTitle(_ line: String) -> (title: String, urls: [URL])? {
		let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
		guard trimmed.hasPrefix("–") || trimmed.hasPrefix("-") else { return nil }

		var rest = trimmed
		if rest.hasPrefix("–") {
			rest.removeFirst()
		} else if rest.hasPrefix("-") {
			rest.removeFirst()
		}
		rest = rest.trimmingCharacters(in: .whitespacesAndNewlines)

		let urls = extractURLs(from: rest)
		var title = rest
		for url in urls {
			title = title.replacingOccurrences(of: url.absoluteString, with: "")
		}

		title = title
			.trimmingCharacters(in: .whitespacesAndNewlines)
			.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
			.trimmingCharacters(in: .whitespacesAndNewlines)

		guard !title.isEmpty else { return nil }
		return (title, urls)
	}

	private static func extractURLs(from line: String) -> [URL] {
		let tokens = line.split(whereSeparator: { $0.isWhitespace })
		var urls: [URL] = []

		for token in tokens {
			let raw = String(token).trimmingCharacters(in: CharacterSet(charactersIn: ".,);]\"'"))
			guard raw.lowercased().hasPrefix("http://") || raw.lowercased().hasPrefix("https://") else { continue }
			if let url = URL(string: raw) {
				urls.append(url)
			}
		}

		return urls
	}

	private static func parseEmailURL(from line: String) -> URL? {
		guard line.contains("@") else { return nil }

		let compact = line.replacingOccurrences(of: " ", with: "")
		let nsLine = compact as NSString
		let range = NSRange(location: 0, length: nsLine.length)
		guard let match = emailRegex.firstMatch(in: compact, range: range) else { return nil }

		let email = nsLine.substring(with: match.range)
		return URL(string: "mailto:\(email)")
	}

	private static func parseLeadingLabel(from line: String) -> String? {
		let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
		guard parts.count >= 1 else { return nil }

		let label = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
		return label.isEmpty ? nil : label
	}

	private static func dedupURLs(_ urls: [URL]) -> [URL] {
		var seen = Set<String>()
		var unique: [URL] = []

		for url in urls {
			let key = url.absoluteString
			guard !seen.contains(key) else { continue }
			seen.insert(key)
			unique.append(url)
		}

		return unique
	}

	private static func makeLinkTitle(baseTitle: String, url _: URL, isDisambiguationNeeded _: Bool) -> String {
		baseTitle
	}
}
