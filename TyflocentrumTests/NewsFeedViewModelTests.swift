import Foundation
import XCTest

@testable import Tyflocentrum

final class NewsFeedViewModelTests: XCTestCase {
	override func tearDown() {
		StubURLProtocol.requestHandler = nil
		super.tearDown()
	}

	@MainActor
	func testRefreshMergesPodcastAndArticlePagesByDate() async {
		StubURLProtocol.requestHandler = { request in
			let url = try XCTUnwrap(request.url)
			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!

			switch url.host {
			case "tyflopodcast.net":
				return (response, Self.postsResponseData(items: [
					Self.postSummaryJSON(id: 1, date: "2026-01-20T00:59:40", title: "P1", link: "https://tyflopodcast.net/?p=1"),
					Self.postSummaryJSON(id: 2, date: "2026-01-18T00:59:40", title: "P2", link: "https://tyflopodcast.net/?p=2"),
				]))
			case "tyfloswiat.pl":
				return (response, Self.postsResponseData(items: [
					Self.postSummaryJSON(id: 3, date: "2026-01-19T00:59:40", title: "A1", link: "https://tyfloswiat.pl/?p=3"),
					Self.postSummaryJSON(id: 4, date: "2026-01-17T00:59:40", title: "A2", link: "https://tyfloswiat.pl/?p=4"),
				]))
			default:
				return (response, Data("[]".utf8))
			}
		}

		let api = TyfloAPI(session: makeSession())
		let viewModel = NewsFeedViewModel(requestTimeoutSeconds: 2)

		await viewModel.refresh(api: api)

		XCTAssertEqual(viewModel.items.count, 4)
		XCTAssertEqual(viewModel.items.map(\.id), [
			"podcast.1",
			"article.3",
			"podcast.2",
			"article.4",
		])
	}

	@MainActor
	func testRefreshShowsErrorWhenBothSourcesFail() async {
		StubURLProtocol.requestHandler = { request in
			let url = try XCTUnwrap(request.url)
			let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
			return (response, Data("[]".utf8))
		}

		let api = TyfloAPI(session: makeSession())
		let viewModel = NewsFeedViewModel(requestTimeoutSeconds: 2)

		await viewModel.refresh(api: api)

		XCTAssertTrue(viewModel.items.isEmpty)
		XCTAssertEqual(viewModel.errorMessage, "Nie udało się pobrać danych. Spróbuj ponownie.")
		XCTAssertTrue(viewModel.hasLoaded)
		XCTAssertFalse(viewModel.isLoading)
	}

	@MainActor
	func testRefreshShowsPartialResultsWhenOneSourceFails() async {
		StubURLProtocol.requestHandler = { request in
			let url = try XCTUnwrap(request.url)

			if url.host == "tyfloswiat.pl" {
				let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
				return (response, Data("[]".utf8))
			}

			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (
				response,
				Self.postsResponseData(items: [
					Self.postSummaryJSON(id: 1, date: "2026-01-20T00:59:40", title: "P1", link: "https://tyflopodcast.net/?p=1"),
				])
			)
		}

		let api = TyfloAPI(session: makeSession())
		let viewModel = NewsFeedViewModel(requestTimeoutSeconds: 2)

		await viewModel.refresh(api: api)

		XCTAssertEqual(viewModel.items.map(\.id), ["podcast.1"])
		XCTAssertNil(viewModel.errorMessage)
	}

	@MainActor
	func testRefreshKeepsExistingItemsWhenRefreshFails() async {
		var stage = 0

		StubURLProtocol.requestHandler = { request in
			let url = try XCTUnwrap(request.url)
			if stage == 1 {
				let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
				return (response, Data("[]".utf8))
			}

			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			switch url.host {
			case "tyflopodcast.net":
				return (
					response,
					Self.postsResponseData(items: [
						Self.postSummaryJSON(id: 1, date: "2026-01-20T00:59:40", title: "P1", link: "https://tyflopodcast.net/?p=1"),
					])
				)
			case "tyfloswiat.pl":
				return (
					response,
					Self.postsResponseData(items: [
						Self.postSummaryJSON(id: 10, date: "2026-01-19T00:59:40", title: "A1", link: "https://tyfloswiat.pl/?p=10"),
					])
				)
			default:
				return (response, Data("[]".utf8))
			}
		}

		let api = TyfloAPI(session: makeSession())
		let viewModel = NewsFeedViewModel(requestTimeoutSeconds: 2)

		await viewModel.refresh(api: api)
		XCTAssertEqual(viewModel.items.map(\.id), ["podcast.1", "article.10"])
		XCTAssertNil(viewModel.errorMessage)

		stage = 1
		await viewModel.refresh(api: api)
		XCTAssertEqual(viewModel.items.map(\.id), ["podcast.1", "article.10"])
		XCTAssertEqual(viewModel.errorMessage, "Nie udało się pobrać danych. Spróbuj ponownie.")
	}

	@MainActor
	func testRefreshRetriesOnceWhenBothSourcesFailTransiently() async {
		var podcastRequests = 0
		var articleRequests = 0

		StubURLProtocol.requestHandler = { request in
			let url = try XCTUnwrap(request.url)

			switch url.host {
			case "tyflopodcast.net":
				podcastRequests += 1
				if podcastRequests <= 2 {
					let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
					return (response, Data("[]".utf8))
				}
				let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
				return (
					response,
					Self.postsResponseData(items: [
						Self.postSummaryJSON(id: 1, date: "2026-01-20T00:59:40", title: "P1", link: "https://tyflopodcast.net/?p=1"),
					])
				)
			case "tyfloswiat.pl":
				articleRequests += 1
				if articleRequests <= 2 {
					let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
					return (response, Data("[]".utf8))
				}
				let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
				return (
					response,
					Self.postsResponseData(items: [
						Self.postSummaryJSON(id: 10, date: "2026-01-19T00:59:40", title: "A1", link: "https://tyfloswiat.pl/?p=10"),
					])
				)
			default:
				let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
				return (response, Data("[]".utf8))
			}
		}

		let api = TyfloAPI(session: makeSession())
		let viewModel = NewsFeedViewModel(requestTimeoutSeconds: 2)

		await viewModel.refresh(api: api)

		XCTAssertEqual(viewModel.items.map(\.id), ["podcast.1", "article.10"])
		XCTAssertNil(viewModel.errorMessage)
		XCTAssertTrue(viewModel.hasLoaded)
		XCTAssertFalse(viewModel.isLoading)
		XCTAssertGreaterThanOrEqual(podcastRequests, 3)
		XCTAssertGreaterThanOrEqual(articleRequests, 3)
	}

	@MainActor
	func testRefreshKeepsChronologicalOrderWhenOneSourcePageContainsVeryOldItems() async {
		StubURLProtocol.requestHandler = { request in
			let url = try XCTUnwrap(request.url)
			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["X-WP-TotalPages": "2"])!

			let page = Int(URLComponents(url: url, resolvingAgainstBaseURL: false)?
				.queryItems?
				.first(where: { $0.name == "page" })?
				.value ?? "1") ?? 1

			switch url.host {
			case "tyflopodcast.net":
				if page == 1 {
					return (response, Self.postsResponseData(items: [
						Self.postSummaryJSON(id: 1, date: "2026-01-20T00:59:40", title: "P1", link: "https://tyflopodcast.net/?p=1"),
						Self.postSummaryJSON(id: 2, date: "2026-01-18T00:59:40", title: "P2", link: "https://tyflopodcast.net/?p=2"),
					]))
				}
				return (response, Self.postsResponseData(items: [
					Self.postSummaryJSON(id: 3, date: "2026-01-17T00:59:40", title: "P3", link: "https://tyflopodcast.net/?p=3"),
					Self.postSummaryJSON(id: 4, date: "2026-01-16T00:59:40", title: "P4", link: "https://tyflopodcast.net/?p=4"),
				]))
			case "tyfloswiat.pl":
				return (response, Self.postsResponseData(items: [
					Self.postSummaryJSON(id: 10, date: "2026-01-19T00:59:40", title: "A1", link: "https://tyfloswiat.pl/?p=10"),
					// Very old item that should not “jump ahead” of still-available newer podcasts.
					Self.postSummaryJSON(id: 11, date: "2025-01-01T00:00:00", title: "A2", link: "https://tyfloswiat.pl/?p=11"),
				]))
			default:
				XCTFail("Unexpected host: \(url.host ?? "<nil>") page=\(page)")
				return (response, Data("[]".utf8))
			}
		}

		let api = TyfloAPI(session: makeSession())
		let viewModel = NewsFeedViewModel(
			requestTimeoutSeconds: 2,
			sourcePerPage: 2,
			initialBatchSize: 4,
			loadMoreBatchSize: 4
		)

		await viewModel.refresh(api: api)

		XCTAssertEqual(viewModel.items.map(\.id), [
			"podcast.1",
			"article.10",
			"podcast.2",
			"podcast.3",
		])
	}

	@MainActor
	func testLoadMoreInFlightDoesNotPolluteRefreshResults() async {
		let lock = NSLock()
		var stage = 0
		var shouldTrackPage2Requests = false
		var shouldBlockFirstPage2Request = true
		let page2Requested = expectation(description: "Page 2 request started")
		let allowPage2ToFinish = DispatchSemaphore(value: 0)

		StubURLProtocol.requestHandler = { request in
			guard let url = request.url else {
				throw URLError(.badURL)
			}
			let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
			let queryItems = components?.queryItems ?? []
			let page = Int(queryItems.first(where: { $0.name == "page" })?.value ?? "1") ?? 1

			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["X-WP-TotalPages": "2"])!

			lock.lock()
			let currentStage = stage
			let shouldBlock = shouldTrackPage2Requests && shouldBlockFirstPage2Request && page == 2
			if shouldBlock {
				shouldBlockFirstPage2Request = false
			}
			lock.unlock()

			if shouldBlock {
				page2Requested.fulfill()
				_ = allowPage2ToFinish.wait(timeout: DispatchTime.now() + .seconds(2))
			}

			let (podcastID, articleID): (Int, Int)
			switch currentStage {
			case 0:
				podcastID = page == 1 ? 1 : 2
				articleID = page == 1 ? 10 : 11
			default:
				podcastID = page == 1 ? 100 : 101
				articleID = page == 1 ? 200 : 201
			}

			switch url.host {
			case "tyflopodcast.net":
				let date = page == 1 ? "2026-01-20T00:59:40" : "2026-01-18T00:59:40"
				return (response, Self.postsResponseData(items: [
					Self.postSummaryJSON(id: podcastID, date: date, title: "P\(podcastID)", link: "https://tyflopodcast.net/?p=\(podcastID)"),
				]))
			case "tyfloswiat.pl":
				let date = page == 1 ? "2026-01-19T00:59:40" : "2026-01-17T00:59:40"
				return (response, Self.postsResponseData(items: [
					Self.postSummaryJSON(id: articleID, date: date, title: "A\(articleID)", link: "https://tyfloswiat.pl/?p=\(articleID)"),
				]))
			default:
				return (response, Data("[]".utf8))
			}
		}

		let api = TyfloAPI(session: makeSession())
		let viewModel = NewsFeedViewModel(
			requestTimeoutSeconds: 2,
			sourcePerPage: 1,
			initialBatchSize: 2,
			loadMoreBatchSize: 1
		)

		await viewModel.refresh(api: api)
		XCTAssertEqual(viewModel.items.map(\.id), ["podcast.1", "article.10"])

		lock.lock()
		shouldTrackPage2Requests = true
		lock.unlock()

		let loadMoreTask = Task { @MainActor in
			await viewModel.loadMore(api: api)
		}

		await fulfillment(of: [page2Requested], timeout: 1)

		lock.lock()
		stage = 1
		lock.unlock()

		await viewModel.refresh(api: api)
		XCTAssertEqual(viewModel.items.map(\.id), ["podcast.100", "article.200"])

		allowPage2ToFinish.signal()
		_ = await loadMoreTask.result

		// The stale load-more result must not be appended to the refreshed feed.
		XCTAssertEqual(viewModel.items.map(\.id), ["podcast.100", "article.200"])
		XCTAssertFalse(viewModel.isLoadingMore)
	}

	private func makeSession() -> URLSession {
		let config = URLSessionConfiguration.ephemeral
		config.protocolClasses = [StubURLProtocol.self]
		return URLSession(configuration: config)
	}

	private static func postSummaryJSON(id: Int, date: String, title: String, link: String) -> String {
		#"""
		{"id":\#(id),"date":"\#(date)","title":{"rendered":"\#(title)"},"excerpt":{"rendered":"Excerpt"},"link":"\#(link)"}
		"""#
	}

	private static func postsResponseData(items: [String]) -> Data {
		Data("[\(items.joined(separator: ","))]".utf8)
	}
}
