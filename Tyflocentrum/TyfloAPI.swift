//
//  TyfloAPI.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 19/10/2022.
//

import Foundation

private actor NoStoreInMemoryCache {
	struct Entry {
		let data: Data
		let expiresAt: Date
		let wpTotal: Int?
		let wpTotalPages: Int?

		var isExpired: Bool {
			Date() >= expiresAt
		}
	}

	private let ttlSeconds: TimeInterval
	private let maxEntries: Int
	private let maxTotalBytes: Int
	private let maxEntryBytes: Int
	private var entries: [URL: Entry] = [:]
	private var totalBytes: Int = 0

	init(ttlSeconds: TimeInterval, maxEntries: Int = 256, maxTotalBytes: Int = 5 * 1024 * 1024, maxEntryBytes: Int = 1024 * 1024) {
		self.ttlSeconds = ttlSeconds
		self.maxEntries = max(1, maxEntries)
		self.maxTotalBytes = max(1, maxTotalBytes)
		self.maxEntryBytes = max(1, maxEntryBytes)
	}

	func get(_ url: URL) -> Entry? {
		guard let entry = entries[url] else { return nil }
		if entry.isExpired {
			removeEntry(for: url)
			return nil
		}
		return entry
	}

	func set(_ url: URL, data: Data, wpTotal: Int? = nil, wpTotalPages: Int? = nil) {
		if data.count > maxEntryBytes {
			removeEntry(for: url)
			return
		}

		let expiresAt = Date().addingTimeInterval(ttlSeconds)
		if let existing = entries[url] {
			totalBytes = max(0, totalBytes - existing.data.count)
		}
		entries[url] = Entry(data: data, expiresAt: expiresAt, wpTotal: wpTotal, wpTotalPages: wpTotalPages)
		totalBytes += data.count
		pruneIfNeeded()
	}

	func remove(_ url: URL) {
		removeEntry(for: url)
	}

	private func pruneIfNeeded() {
		guard entries.count > maxEntries || totalBytes > maxTotalBytes else { return }

		let now = Date()
		let expiredKeys = entries.compactMap { key, value in
			value.expiresAt <= now ? key : nil
		}
		for key in expiredKeys {
			removeEntry(for: key)
		}

		guard entries.count > maxEntries || totalBytes > maxTotalBytes else { return }

		let victims = entries
			.sorted(by: { $0.value.expiresAt < $1.value.expiresAt })
			.map(\.key)

		for key in victims {
			guard entries.count > maxEntries || totalBytes > maxTotalBytes else { return }
			removeEntry(for: key)
		}
	}

	private func removeEntry(for url: URL) {
		if let existing = entries[url] {
			totalBytes = max(0, totalBytes - existing.data.count)
		}
		entries[url] = nil
	}
}

final class TyfloAPI: ObservableObject {
	private let session: URLSession
	private let tyfloPodcastBaseURL = URL(string: "https://tyflopodcast.net/wp-json")!
	private let tyfloWorldBaseURL = URL(string: "https://tyfloswiat.pl/wp-json")!
	private let tyfloPodcastAPIURL = URL(string: "https://kontakt.tyflopodcast.net/json.php")!
	private let wpPostFields = "id,date,title,excerpt,content,guid"
	private let wpEmbedPostFields = "id,date,link,title,excerpt"
	private let wpCategoryFields = "id,name,count"

	private static let requestTimeoutSeconds: TimeInterval = 30
	private static let retryableErrorCodes: Set<URLError.Code> = [
		.notConnectedToInternet,
		.timedOut,
		.cancelled,
		.cannotFindHost,
		.cannotConnectToHost,
		.networkConnectionLost,
		.dnsLookupFailed,
		.badServerResponse,
		.cannotDecodeContentData,
		.cannotParseResponse,
	]

	private static func makeSharedSession() -> URLSession {
		let config = URLSessionConfiguration.default
		config.waitsForConnectivity = true
		config.timeoutIntervalForRequest = requestTimeoutSeconds
		config.timeoutIntervalForResource = requestTimeoutSeconds
		return URLSession(configuration: config)
	}

	static let shared = TyfloAPI(session: makeSharedSession())

	struct NoStoreCacheConfig: Equatable {
		var ttlSeconds: TimeInterval = 5 * 60
		var maxEntries: Int = 256
		var maxTotalBytes: Int = 5 * 1024 * 1024
		var maxEntryBytes: Int = 1024 * 1024
	}

	private let noStoreCache: NoStoreInMemoryCache
	init(session: URLSession = .shared, noStoreCacheConfig: NoStoreCacheConfig = .init()) {
		self.session = session
		noStoreCache = NoStoreInMemoryCache(
			ttlSeconds: noStoreCacheConfig.ttlSeconds,
			maxEntries: noStoreCacheConfig.maxEntries,
			maxTotalBytes: noStoreCacheConfig.maxTotalBytes,
			maxEntryBytes: noStoreCacheConfig.maxEntryBytes
		)
	}

	struct WPPage<Item: Decodable> {
		let items: [Item]
		let total: Int?
		let totalPages: Int?
	}

	struct RadioSchedule: Decodable, Equatable {
		let available: Bool
		let text: String?
		let error: String?

		init(available: Bool, text: String?, error: String? = nil) {
			self.available = available
			self.text = text
			self.error = error
		}
	}

	private func makeWPURL(baseURL: URL, path: String, queryItems: [URLQueryItem]) -> URL? {
		guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else { return nil }
		components.queryItems = queryItems.isEmpty ? nil : queryItems
		return components.url
	}

	private static func isRetryableError(_ error: Error) -> Bool {
		if error is AsyncTimeoutError {
			return true
		}
		if error is CancellationError {
			return false
		}
		if let urlError = error as? URLError {
			return retryableErrorCodes.contains(urlError.code)
		}
		return false
	}

	private static func retryDelayNanoseconds(forAttempt attempt: Int) -> UInt64 {
		switch attempt {
		case 1:
			return 250_000_000
		default:
			return 500_000_000
		}
	}

	private static func shouldUseNoStoreCache(for http: HTTPURLResponse) -> Bool {
		guard let cacheControl = http.value(forHTTPHeaderField: "Cache-Control")?.lowercased() else {
			return false
		}
		return cacheControl.contains("no-store")
	}

	private static func safeLogURLString(_ url: URL) -> String {
		guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
			return "\(url.host ?? "")\(url.path)"
		}
		components.query = nil
		components.fragment = nil
		return components.url?.absoluteString ?? "\(url.host ?? "")\(url.path)"
	}

	private func withRetry<T>(
		maxAttempts: Int = 2,
		operation: @escaping () async throws -> T
	) async throws -> T {
		precondition(maxAttempts > 0)

		var attempt = 0
		while true {
			attempt += 1
			do {
				return try await operation()
			} catch {
				if Task.isCancelled {
					throw error
				}
				guard attempt < maxAttempts, Self.isRetryableError(error) else {
					throw error
				}
				try? await Task.sleep(nanoseconds: Self.retryDelayNanoseconds(forAttempt: attempt))
			}
		}
	}

	private func fetch<T: Decodable>(
		_ url: URL,
		decoder: JSONDecoder = JSONDecoder(),
		cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
	) async throws -> T {
		if cachePolicy == .useProtocolCachePolicy, let cached = await noStoreCache.get(url) {
			if let decoded = try? decoder.decode(T.self, from: cached.data) {
				return decoded
			}
			await noStoreCache.remove(url)
		}

		var request = URLRequest(url: url)
		request.cachePolicy = cachePolicy
		request.timeoutInterval = Self.requestTimeoutSeconds
		request.setValue("application/json", forHTTPHeaderField: "Accept")

		return try await withRetry {
			let (data, response) = try await self.session.data(for: request)
			guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
				throw URLError(.badServerResponse)
			}

			if cachePolicy == .useProtocolCachePolicy, Self.shouldUseNoStoreCache(for: http) {
				await self.noStoreCache.set(url, data: data)
			}

			do {
				return try decoder.decode(T.self, from: data)
			} catch {
				throw URLError(.cannotDecodeContentData)
			}
		}
	}

	private func fetchWPPage<Item: Decodable>(
		_ url: URL,
		decoder: JSONDecoder = JSONDecoder(),
		cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
	) async throws -> WPPage<Item> {
		if cachePolicy == .useProtocolCachePolicy, let cached = await noStoreCache.get(url) {
			if let decodedItems = try? decoder.decode([Item].self, from: cached.data) {
				return WPPage(items: decodedItems, total: cached.wpTotal, totalPages: cached.wpTotalPages)
			}
			await noStoreCache.remove(url)
		}

		var request = URLRequest(url: url)
		request.cachePolicy = cachePolicy
		request.timeoutInterval = Self.requestTimeoutSeconds
		request.setValue("application/json", forHTTPHeaderField: "Accept")

		return try await withRetry {
			let (data, response) = try await self.session.data(for: request)
			guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
				throw URLError(.badServerResponse)
			}

			let items: [Item]
			do {
				items = try decoder.decode([Item].self, from: data)
			} catch {
				throw URLError(.cannotDecodeContentData)
			}

			let total = http.value(forHTTPHeaderField: "X-WP-Total").flatMap(Int.init)
			let totalPages = http.value(forHTTPHeaderField: "X-WP-TotalPages").flatMap(Int.init)

			if cachePolicy == .useProtocolCachePolicy, Self.shouldUseNoStoreCache(for: http) {
				await self.noStoreCache.set(url, data: data, wpTotal: total, wpTotalPages: totalPages)
			}

			return WPPage(items: items, total: total, totalPages: totalPages)
		}
	}

	func fetchLatestPodcasts() async throws -> [Podcast] {
		guard let url = makeWPURL(
			baseURL: tyfloPodcastBaseURL,
			path: "wp/v2/posts",
			queryItems: [URLQueryItem(name: "per_page", value: "100")]
		) else {
			throw URLError(.badURL)
		}
		return try await fetch(url)
	}

	func fetchLatestArticles() async throws -> [Podcast] {
		guard let url = makeWPURL(
			baseURL: tyfloWorldBaseURL,
			path: "wp/v2/posts",
			queryItems: [URLQueryItem(name: "per_page", value: "100")]
		) else {
			throw URLError(.badURL)
		}
		return try await fetch(url)
	}

	func fetchPodcastSummariesPage(page: Int, perPage: Int, categoryID: Int? = nil) async throws -> WPPage<WPPostSummary> {
		guard page > 0 else { return WPPage(items: [], total: nil, totalPages: nil) }
		guard perPage > 0 else { return WPPage(items: [], total: nil, totalPages: nil) }

		var queryItems: [URLQueryItem] = [
			URLQueryItem(name: "context", value: "embed"),
			URLQueryItem(name: "per_page", value: "\(perPage)"),
			URLQueryItem(name: "page", value: "\(page)"),
			URLQueryItem(name: "orderby", value: "date"),
			URLQueryItem(name: "order", value: "desc"),
			URLQueryItem(name: "_fields", value: wpEmbedPostFields),
		]
		if let categoryID {
			queryItems.append(URLQueryItem(name: "categories", value: "\(categoryID)"))
		}

		guard let url = makeWPURL(
			baseURL: tyfloPodcastBaseURL,
			path: "wp/v2/posts",
			queryItems: queryItems
		) else {
			throw URLError(.badURL)
		}

		return try await fetchWPPage(url)
	}

	func fetchArticleSummariesPage(page: Int, perPage: Int, categoryID: Int? = nil) async throws -> WPPage<WPPostSummary> {
		guard page > 0 else { return WPPage(items: [], total: nil, totalPages: nil) }
		guard perPage > 0 else { return WPPage(items: [], total: nil, totalPages: nil) }

		var queryItems: [URLQueryItem] = [
			URLQueryItem(name: "context", value: "embed"),
			URLQueryItem(name: "per_page", value: "\(perPage)"),
			URLQueryItem(name: "page", value: "\(page)"),
			URLQueryItem(name: "orderby", value: "date"),
			URLQueryItem(name: "order", value: "desc"),
			URLQueryItem(name: "_fields", value: wpEmbedPostFields),
		]
		if let categoryID {
			queryItems.append(URLQueryItem(name: "categories", value: "\(categoryID)"))
		}

		guard let url = makeWPURL(
			baseURL: tyfloWorldBaseURL,
			path: "wp/v2/posts",
			queryItems: queryItems
		) else {
			throw URLError(.badURL)
		}

		return try await fetchWPPage(url)
	}

	func fetchPodcast(id: Int) async throws -> Podcast {
		guard let url = makeWPURL(
			baseURL: tyfloPodcastBaseURL,
			path: "wp/v2/posts/\(id)",
			queryItems: [
				URLQueryItem(name: "_fields", value: wpPostFields),
			]
		) else {
			throw URLError(.badURL)
		}
		return try await fetch(url)
	}

	func fetchArticle(id: Int) async throws -> Podcast {
		guard let url = makeWPURL(
			baseURL: tyfloWorldBaseURL,
			path: "wp/v2/posts/\(id)",
			queryItems: [
				URLQueryItem(name: "_fields", value: wpPostFields),
			]
		) else {
			throw URLError(.badURL)
		}
		return try await fetch(url)
	}

	func getLatestPodcasts() async -> [Podcast] {
		do {
			return try await fetchLatestPodcasts()
		} catch {
			AppLog.network.error("Failed to fetch latest podcasts. Error: \(error.localizedDescription, privacy: .public)")
			return [Podcast]()
		}
	}

	func fetchCategories() async throws -> [Category] {
		guard let url = makeWPURL(
			baseURL: tyfloPodcastBaseURL,
			path: "wp/v2/categories",
			queryItems: [
				URLQueryItem(name: "per_page", value: "100"),
				URLQueryItem(name: "orderby", value: "name"),
				URLQueryItem(name: "order", value: "asc"),
				URLQueryItem(name: "_fields", value: wpCategoryFields),
			]
		) else {
			throw URLError(.badURL)
		}
		return try await fetch(url)
	}

	func getCategories() async -> [Category] {
		do {
			return try await fetchCategories()
		} catch {
			AppLog.network.error("Failed to fetch podcast categories. Error: \(error.localizedDescription, privacy: .public)")
			return [Category]()
		}
	}

	func fetchPodcasts(for category: Category) async throws -> [Podcast] {
		guard let url = makeWPURL(
			baseURL: tyfloPodcastBaseURL,
			path: "wp/v2/posts",
			queryItems: [
				URLQueryItem(name: "categories", value: "\(category.id)"),
				URLQueryItem(name: "per_page", value: "100"),
			]
		) else {
			throw URLError(.badURL)
		}
		return try await fetch(url)
	}

	func getPodcast(for category: Category) async -> [Podcast] {
		do {
			return try await fetchPodcasts(for: category)
		} catch {
			AppLog.network.error(
				"Failed to fetch podcasts for category id=\(category.id). Error: \(error.localizedDescription, privacy: .public)"
			)
			return [Podcast]()
		}
	}

	func fetchArticleCategories() async throws -> [Category] {
		guard let url = makeWPURL(
			baseURL: tyfloWorldBaseURL,
			path: "wp/v2/categories",
			queryItems: [
				URLQueryItem(name: "per_page", value: "100"),
				URLQueryItem(name: "orderby", value: "name"),
				URLQueryItem(name: "order", value: "asc"),
				URLQueryItem(name: "_fields", value: wpCategoryFields),
			]
		) else {
			throw URLError(.badURL)
		}
		return try await fetch(url)
	}

	func fetchPodcastCategoriesPage(page: Int, perPage: Int) async throws -> WPPage<Category> {
		guard page > 0 else { return WPPage(items: [], total: nil, totalPages: nil) }
		guard perPage > 0 else { return WPPage(items: [], total: nil, totalPages: nil) }

		guard let url = makeWPURL(
			baseURL: tyfloPodcastBaseURL,
			path: "wp/v2/categories",
			queryItems: [
				URLQueryItem(name: "per_page", value: "\(perPage)"),
				URLQueryItem(name: "page", value: "\(page)"),
				URLQueryItem(name: "orderby", value: "name"),
				URLQueryItem(name: "order", value: "asc"),
				URLQueryItem(name: "_fields", value: wpCategoryFields),
			]
		) else {
			throw URLError(.badURL)
		}

		return try await fetchWPPage(url)
	}

	func fetchArticleCategoriesPage(page: Int, perPage: Int) async throws -> WPPage<Category> {
		guard page > 0 else { return WPPage(items: [], total: nil, totalPages: nil) }
		guard perPage > 0 else { return WPPage(items: [], total: nil, totalPages: nil) }

		guard let url = makeWPURL(
			baseURL: tyfloWorldBaseURL,
			path: "wp/v2/categories",
			queryItems: [
				URLQueryItem(name: "per_page", value: "\(perPage)"),
				URLQueryItem(name: "page", value: "\(page)"),
				URLQueryItem(name: "orderby", value: "name"),
				URLQueryItem(name: "order", value: "asc"),
				URLQueryItem(name: "_fields", value: wpCategoryFields),
			]
		) else {
			throw URLError(.badURL)
		}

		return try await fetchWPPage(url)
	}

	func getArticleCategories() async -> [Category] {
		do {
			return try await fetchArticleCategories()
		} catch {
			AppLog.network.error("Failed to fetch article categories. Error: \(error.localizedDescription, privacy: .public)")
			return [Category]()
		}
	}

	func fetchArticles(for category: Category) async throws -> [Podcast] {
		guard let url = makeWPURL(
			baseURL: tyfloWorldBaseURL,
			path: "wp/v2/posts",
			queryItems: [
				URLQueryItem(name: "categories", value: "\(category.id)"),
				URLQueryItem(name: "per_page", value: "100"),
			]
		) else {
			throw URLError(.badURL)
		}
		return try await fetch(url)
	}

	func getArticles(for category: Category) async -> [Podcast] {
		do {
			return try await fetchArticles(for: category)
		} catch {
			AppLog.network.error(
				"Failed to fetch articles for category id=\(category.id). Error: \(error.localizedDescription, privacy: .public)"
			)
			return [Podcast]()
		}
	}

	func getListenableURL(for podcast: Podcast) -> URL {
		guard var components = URLComponents(string: "https://tyflopodcast.net/pobierz.php") else {
			return URL(string: "https://tyflopodcast.net")!
		}
		components.queryItems = [
			URLQueryItem(name: "id", value: "\(podcast.id)"),
			URLQueryItem(name: "plik", value: "0"),
		]
		return components.url ?? URL(string: "https://tyflopodcast.net")!
	}

	func fetchPodcasts(matching searchString: String) async throws -> [Podcast] {
		let trimmed = searchString.trimmingCharacters(in: .whitespacesAndNewlines)
		guard let url = makeWPURL(
			baseURL: tyfloPodcastBaseURL,
			path: "wp/v2/posts",
			queryItems: [
				URLQueryItem(name: "per_page", value: "100"),
				URLQueryItem(name: "search", value: trimmed.lowercased()),
			]
		) else {
			throw URLError(.badURL)
		}
		return try await fetch(url)
	}

	func fetchPodcastSearchSummaries(matching searchString: String) async throws -> [WPPostSummary] {
		let trimmed = searchString.trimmingCharacters(in: .whitespacesAndNewlines)
		guard let url = makeWPURL(
			baseURL: tyfloPodcastBaseURL,
			path: "wp/v2/posts",
			queryItems: [
				URLQueryItem(name: "context", value: "embed"),
				URLQueryItem(name: "per_page", value: "100"),
				URLQueryItem(name: "search", value: trimmed),
				URLQueryItem(name: "orderby", value: "date"),
				URLQueryItem(name: "order", value: "desc"),
				URLQueryItem(name: "_fields", value: wpEmbedPostFields),
			]
		) else {
			throw URLError(.badURL)
		}
		return try await fetch(url)
	}

	func fetchArticleSearchSummaries(matching searchString: String) async throws -> [WPPostSummary] {
		let trimmed = searchString.trimmingCharacters(in: .whitespacesAndNewlines)
		guard let url = makeWPURL(
			baseURL: tyfloWorldBaseURL,
			path: "wp/v2/posts",
			queryItems: [
				URLQueryItem(name: "context", value: "embed"),
				URLQueryItem(name: "per_page", value: "100"),
				URLQueryItem(name: "search", value: trimmed),
				URLQueryItem(name: "orderby", value: "date"),
				URLQueryItem(name: "order", value: "desc"),
				URLQueryItem(name: "_fields", value: wpEmbedPostFields),
			]
		) else {
			throw URLError(.badURL)
		}
		return try await fetch(url)
	}

	func fetchTyfloswiatPages(slug: String, perPage: Int = 100) async throws -> [WPPostSummary] {
		guard let url = makeWPURL(
			baseURL: tyfloWorldBaseURL,
			path: "wp/v2/pages",
			queryItems: [
				URLQueryItem(name: "context", value: "embed"),
				URLQueryItem(name: "per_page", value: "\(perPage)"),
				URLQueryItem(name: "slug", value: slug),
				URLQueryItem(name: "_fields", value: wpEmbedPostFields),
			]
		) else {
			throw URLError(.badURL)
		}
		return try await fetch(url)
	}

	func fetchTyfloswiatPageSummaries(parentPageID: Int, perPage: Int = 100) async throws -> [WPPostSummary] {
		guard let url = makeWPURL(
			baseURL: tyfloWorldBaseURL,
			path: "wp/v2/pages",
			queryItems: [
				URLQueryItem(name: "context", value: "embed"),
				URLQueryItem(name: "per_page", value: "\(perPage)"),
				URLQueryItem(name: "parent", value: "\(parentPageID)"),
				URLQueryItem(name: "orderby", value: "date"),
				URLQueryItem(name: "order", value: "desc"),
				URLQueryItem(name: "_fields", value: wpEmbedPostFields),
			]
		) else {
			throw URLError(.badURL)
		}
		return try await fetch(url)
	}

	func fetchTyfloswiatPage(id: Int) async throws -> Podcast {
		guard let url = makeWPURL(
			baseURL: tyfloWorldBaseURL,
			path: "wp/v2/pages/\(id)",
			queryItems: [
				URLQueryItem(name: "_fields", value: wpPostFields),
			]
		) else {
			throw URLError(.badURL)
		}
		return try await fetch(url)
	}

	func getPodcasts(for searchString: String) async -> [Podcast] {
		do {
			return try await fetchPodcasts(matching: searchString)
		} catch {
			AppLog.network.error("Failed to search podcasts. Error: \(error.localizedDescription, privacy: .public)")
			return [Podcast]()
		}
	}

	func fetchComments(forPostID postID: Int) async throws -> [Comment] {
		guard let url = makeWPURL(
			baseURL: tyfloPodcastBaseURL,
			path: "wp/v2/comments",
			queryItems: [
				URLQueryItem(name: "post", value: "\(postID)"),
				URLQueryItem(name: "per_page", value: "100"),
			]
		) else {
			throw URLError(.badURL)
		}

		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		return try await fetch(url, decoder: decoder)
	}

	func fetchCommentsPage(
		forPostID postID: Int,
		page: Int,
		perPage: Int,
		cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
	) async throws -> WPPage<Comment> {
		guard page > 0 else { return WPPage(items: [], total: nil, totalPages: nil) }
		guard perPage > 0 else { return WPPage(items: [], total: nil, totalPages: nil) }

		guard let url = makeWPURL(
			baseURL: tyfloPodcastBaseURL,
			path: "wp/v2/comments",
			queryItems: [
				URLQueryItem(name: "post", value: "\(postID)"),
				URLQueryItem(name: "per_page", value: "\(perPage)"),
				URLQueryItem(name: "page", value: "\(page)"),
			]
		) else {
			throw URLError(.badURL)
		}

		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		return try await fetchWPPage(url, decoder: decoder, cachePolicy: cachePolicy)
	}

	func fetchCommentsCount(forPostID postID: Int) async throws -> Int {
		// Always bypass URLCache for "meta" checks (count), because we observed stale totals on first open on device.
		let firstPage = try await fetchCommentsPage(
			forPostID: postID,
			page: 1,
			perPage: 1,
			cachePolicy: .reloadIgnoringLocalCacheData
		)
		if let total = firstPage.total {
			return total
		}
		// Fallback for unexpected WP configurations that don't provide `X-WP-Total`.
		return try await fetchComments(forPostID: postID).count
	}

	func getComments(forPostID postID: Int) async -> [Comment] {
		do {
			return try await fetchComments(forPostID: postID)
		} catch {
			AppLog.network.error(
				"Failed to fetch comments for post id=\(postID). Error: \(error.localizedDescription, privacy: .public)"
			)
			return [Comment]()
		}
	}

	func getComments(for podcast: Podcast) async -> [Comment] {
		await getComments(forPostID: podcast.id)
	}

	func isTPAvailable() async -> (Bool, Availability) {
		guard var components = URLComponents(url: tyfloPodcastAPIURL, resolvingAgainstBaseURL: false) else {
			return (false, Availability(available: false, title: nil))
		}
		components.queryItems = [URLQueryItem(name: "ac", value: "current")]
		guard let url = components.url else {
			return (false, Availability(available: false, title: nil))
		}
		do {
			let decoder = JSONDecoder()
			decoder.keyDecodingStrategy = .convertFromSnakeCase
			let decodedResponse: Availability = try await fetch(url, decoder: decoder, cachePolicy: .reloadIgnoringLocalCacheData)
			return (decodedResponse.available, decodedResponse)
		} catch {
			AppLog.network.error(
				"Failed to fetch TP availability. Error: \(error.localizedDescription, privacy: .public) endpoint=\(Self.safeLogURLString(url), privacy: .public)"
			)
			return (false, Availability(available: false, title: nil))
		}
	}

	func getRadioSchedule() async -> (Bool, RadioSchedule) {
		guard var components = URLComponents(url: tyfloPodcastAPIURL, resolvingAgainstBaseURL: false) else {
			return (false, RadioSchedule(available: false, text: nil, error: "Nie udało się pobrać ramówki. Spróbuj ponownie."))
		}
		components.queryItems = [URLQueryItem(name: "ac", value: "schedule")]
		guard let url = components.url else {
			return (false, RadioSchedule(available: false, text: nil, error: "Nie udało się pobrać ramówki. Spróbuj ponownie."))
		}
		do {
			let decodedResponse: RadioSchedule = try await fetch(url, cachePolicy: .reloadIgnoringLocalCacheData)
			if let error = decodedResponse.error, !error.isEmpty {
				return (false, decodedResponse)
			}
			return (true, decodedResponse)
		} catch {
			AppLog.network.error(
				"Failed to fetch radio schedule. Error: \(error.localizedDescription, privacy: .public) endpoint=\(Self.safeLogURLString(url), privacy: .public)"
			)
			return (false, RadioSchedule(available: false, text: nil, error: "Nie udało się pobrać ramówki. Spróbuj ponownie."))
		}
	}

	func contactRadio(as name: String, with message: String) async -> (Bool, String?) {
		guard var components = URLComponents(url: tyfloPodcastAPIURL, resolvingAgainstBaseURL: false) else {
			return (false, nil)
		}
		components.queryItems = [URLQueryItem(name: "ac", value: "add")]
		guard let url = components.url else {
			return (false, nil)
		}
		let contact = ContactResponse(author: name, comment: message, error: nil)
		var request = URLRequest(url: url)
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.httpMethod = "POST"
		do {
			let encoded = try JSONEncoder().encode(contact)
			let (data, response) = try await session.upload(for: request, from: encoded)
			guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
				return (false, nil)
			}
			let decodedResponse = try JSONDecoder().decode(ContactResponse.self, from: data)
			if let error = decodedResponse.error {
				return (false, error)
			}
			return (true, nil)
		} catch {
			AppLog.network.error(
				"Failed to send contact message. Error: \(error.localizedDescription, privacy: .public) endpoint=\(Self.safeLogURLString(url), privacy: .public)"
			)
			return (false, nil)
		}
	}

	private struct VoiceContactResponse: Decodable {
		let author: String?
		let durationMs: Int?
		let error: String?
	}

	func contactRadioVoice(as name: String, audioFileURL: URL, durationMs: Int) async -> (Bool, String?) {
		guard var components = URLComponents(url: tyfloPodcastAPIURL, resolvingAgainstBaseURL: false) else {
			return (false, nil)
		}
		components.queryItems = [URLQueryItem(name: "ac", value: "addvoice")]
		guard let url = components.url else {
			return (false, nil)
		}

		let boundary = "Boundary-\(UUID().uuidString)"
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.cachePolicy = .reloadIgnoringLocalCacheData
		request.timeoutInterval = Self.requestTimeoutSeconds
		request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
		request.setValue("application/json", forHTTPHeaderField: "Accept")

		let fileName = audioFileURL.lastPathComponent.isEmpty ? "voice.m4a" : audioFileURL.lastPathComponent
		let bodyFileURL: URL
		do {
			bodyFileURL = try MultipartFormDataBuilder.buildBodyFile(
				boundary: boundary,
				fields: [
					"author": name,
					"duration_ms": "\(durationMs)",
				],
				file: MultipartFormDataBuilder.FilePart(
					fieldName: "audio",
					fileURL: audioFileURL,
					fileName: fileName,
					mimeType: "audio/mp4"
				)
			)
		} catch {
			return (false, "Nie udało się przygotować pliku do wysyłki.")
		}
		defer { try? FileManager.default.removeItem(at: bodyFileURL) }

		do {
			let (data, response) = try await session.upload(for: request, fromFile: bodyFileURL)
			guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
				return (false, nil)
			}
			let decoder = JSONDecoder()
			decoder.keyDecodingStrategy = .convertFromSnakeCase
			let decodedResponse = try decoder.decode(VoiceContactResponse.self, from: data)
			if let error = decodedResponse.error {
				return (false, error)
			}
			return (true, nil)
		} catch {
			AppLog.network.error(
				"Failed to send voice contact message. Error: \(error.localizedDescription, privacy: .public) endpoint=\(Self.safeLogURLString(url), privacy: .public)"
			)
			return (false, nil)
		}
	}
}
