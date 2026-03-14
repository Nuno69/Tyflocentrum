import Foundation
import XCTest

@testable import Tyflocentrum

final class TyfloAPITests: XCTestCase {
	override func tearDown() {
		StubURLProtocol.requestHandler = nil
		super.tearDown()
	}

	func testGetListenableURLBuildsExpectedQueryItems() throws {
		let api = TyfloAPI(session: makeSession())
		let url = api.getListenableURL(for: makePodcast(id: 123))

		let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
		XCTAssertEqual(components.host, "tyflopodcast.net")
		XCTAssertEqual(components.path, "/pobierz.php")

		let items = components.queryItems ?? []
		XCTAssertEqual(items.first(where: { $0.name == "id" })?.value, "123")
		XCTAssertEqual(items.first(where: { $0.name == "plik" })?.value, "0")
	}

	func testSearchEncodesQueryAndUsesPerPage100() async {
		let requestMade = expectation(description: "request made")

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)

			XCTAssertEqual(url.host, "tyflopodcast.net")
			XCTAssertTrue(url.path.contains("/wp/v2/posts"))

			let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
			let items = components.queryItems ?? []
			XCTAssertEqual(items.first(where: { $0.name == "per_page" })?.value, "100")
			XCTAssertEqual(items.first(where: { $0.name == "search" })?.value, "ala ma kota")

			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (response, Data("[]".utf8))
		}

		let api = TyfloAPI(session: makeSession())
		_ = await api.getPodcasts(for: "Ala ma kota")

		await fulfillment(of: [requestMade], timeout: 1)
	}

	func testFetchPodcastSearchSummariesUsesEmbedFieldsAndSearchQuery() async {
		let requestMade = expectation(description: "request made")

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)

			XCTAssertEqual(url.host, "tyflopodcast.net")
			XCTAssertTrue(url.path.contains("/wp-json/wp/v2/posts"))
			XCTAssertEqual(request.cachePolicy, .useProtocolCachePolicy)

			let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
			let items = components.queryItems ?? []
			XCTAssertEqual(items.first(where: { $0.name == "context" })?.value, "embed")
			XCTAssertEqual(items.first(where: { $0.name == "per_page" })?.value, "100")
			XCTAssertEqual(items.first(where: { $0.name == "search" })?.value, "Ala ma kota")
			XCTAssertEqual(items.first(where: { $0.name == "_fields" })?.value, "id,date,link,title,excerpt")

			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (response, Data("[]".utf8))
		}

		let api = TyfloAPI(session: makeSession())
		do {
			let results = try await api.fetchPodcastSearchSummaries(matching: "  Ala ma kota ")
			XCTAssertTrue(results.isEmpty)
		} catch {
			XCTFail("Expected success but got error: \(error)")
		}

		await fulfillment(of: [requestMade], timeout: 1)
	}

	func testFetchArticleSearchSummariesUsesWorldHostAndEmbedFields() async {
		let requestMade = expectation(description: "request made")

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)

			XCTAssertEqual(url.host, "tyfloswiat.pl")
			XCTAssertTrue(url.path.contains("/wp-json/wp/v2/posts"))

			let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
			let items = components.queryItems ?? []
			XCTAssertEqual(items.first(where: { $0.name == "context" })?.value, "embed")
			XCTAssertEqual(items.first(where: { $0.name == "per_page" })?.value, "100")
			XCTAssertEqual(items.first(where: { $0.name == "search" })?.value, "Test")
			XCTAssertEqual(items.first(where: { $0.name == "_fields" })?.value, "id,date,link,title,excerpt")

			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (response, Data("[]".utf8))
		}

		let api = TyfloAPI(session: makeSession())
		do {
			let results = try await api.fetchArticleSearchSummaries(matching: "Test")
			XCTAssertTrue(results.isEmpty)
		} catch {
			XCTFail("Expected success but got error: \(error)")
		}

		await fulfillment(of: [requestMade], timeout: 1)
	}

	func testFetchTyfloswiatPagesUsesPagesEndpointAndSlugQuery() async {
		let requestMade = expectation(description: "request made")

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)

			XCTAssertEqual(url.host, "tyfloswiat.pl")
			XCTAssertTrue(url.path.contains("/wp-json/wp/v2/pages"))

			let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
			let items = components.queryItems ?? []
			XCTAssertEqual(items.first(where: { $0.name == "context" })?.value, "embed")
			XCTAssertEqual(items.first(where: { $0.name == "per_page" })?.value, "1")
			XCTAssertEqual(items.first(where: { $0.name == "slug" })?.value, "czasopismo")
			XCTAssertEqual(items.first(where: { $0.name == "_fields" })?.value, "id,date,link,title,excerpt")

			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (response, Data("[]".utf8))
		}

		let api = TyfloAPI(session: makeSession())
		do {
			let results = try await api.fetchTyfloswiatPages(slug: "czasopismo", perPage: 1)
			XCTAssertTrue(results.isEmpty)
		} catch {
			XCTFail("Expected success but got error: \(error)")
		}

		await fulfillment(of: [requestMade], timeout: 1)
	}

	func testFetchTyfloswiatPageSummariesUsesParentAndEmbedFields() async {
		let requestMade = expectation(description: "request made")

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)

			XCTAssertEqual(url.host, "tyfloswiat.pl")
			XCTAssertTrue(url.path.contains("/wp-json/wp/v2/pages"))

			let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
			let items = components.queryItems ?? []
			XCTAssertEqual(items.first(where: { $0.name == "context" })?.value, "embed")
			XCTAssertEqual(items.first(where: { $0.name == "per_page" })?.value, "100")
			XCTAssertEqual(items.first(where: { $0.name == "parent" })?.value, "1409")
			XCTAssertEqual(items.first(where: { $0.name == "orderby" })?.value, "date")
			XCTAssertEqual(items.first(where: { $0.name == "order" })?.value, "desc")
			XCTAssertEqual(items.first(where: { $0.name == "_fields" })?.value, "id,date,link,title,excerpt")

			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (response, Data("[]".utf8))
		}

		let api = TyfloAPI(session: makeSession())
		do {
			let results = try await api.fetchTyfloswiatPageSummaries(parentPageID: 1409, perPage: 100)
			XCTAssertTrue(results.isEmpty)
		} catch {
			XCTFail("Expected success but got error: \(error)")
		}

		await fulfillment(of: [requestMade], timeout: 1)
	}

	func testFetchTyfloswiatPageUsesPageEndpoint() async {
		let requestMade = expectation(description: "request made")

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)

			XCTAssertEqual(url.host, "tyfloswiat.pl")
			XCTAssertTrue(url.path.contains("/wp-json/wp/v2/pages/123"))

			let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
			let items = components.queryItems ?? []
			XCTAssertEqual(items.first(where: { $0.name == "_fields" })?.value, "id,date,title,excerpt,content,guid")

			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			let payload = #"""
			{"id":123,"date":"2026-01-20T00:59:40","title":{"rendered":"Test"},"excerpt":{"rendered":"Excerpt"},"content":{"rendered":"Content"},"guid":{"rendered":"https://tyfloswiat.pl/?page_id=123"}}
			"""#.data(using: .utf8) ?? Data()
			return (response, payload)
		}

		let api = TyfloAPI(session: makeSession())
		do {
			let page = try await api.fetchTyfloswiatPage(id: 123)
			XCTAssertEqual(page.id, 123)
		} catch {
			XCTFail("Expected success but got error: \(error)")
		}

		await fulfillment(of: [requestMade], timeout: 1)
	}

	func testGetLatestPodcastsUsesPerPage100() async {
		let requestMade = expectation(description: "request made")

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)

			XCTAssertEqual(url.host, "tyflopodcast.net")
			XCTAssertTrue(url.path.contains("/wp-json/wp/v2/posts"))
			XCTAssertEqual(request.cachePolicy, .useProtocolCachePolicy)

			let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
			let items = components.queryItems ?? []
			XCTAssertEqual(items.first(where: { $0.name == "per_page" })?.value, "100")

			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (response, self.podcastsResponseData(ids: [1]))
		}

		let api = TyfloAPI(session: makeSession())
		let podcasts = await api.getLatestPodcasts()

		XCTAssertEqual(podcasts.count, 1)
		XCTAssertEqual(podcasts.first?.id, 1)

		await fulfillment(of: [requestMade], timeout: 1)
	}

	func testFetchPodcastSummariesPageUsesPerPageAndPageParameters() async {
		let requestMade = expectation(description: "request made")

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)

			XCTAssertEqual(url.host, "tyflopodcast.net")
			XCTAssertTrue(url.path.contains("/wp-json/wp/v2/posts"))

			let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
			let items = components.queryItems ?? []
			XCTAssertEqual(items.first(where: { $0.name == "context" })?.value, "embed")
			XCTAssertEqual(items.first(where: { $0.name == "per_page" })?.value, "20")
			XCTAssertEqual(items.first(where: { $0.name == "page" })?.value, "2")

			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (response, Data("[]".utf8))
		}

		let api = TyfloAPI(session: makeSession())
		do {
			let page = try await api.fetchPodcastSummariesPage(page: 2, perPage: 20)
			XCTAssertTrue(page.items.isEmpty)
		} catch {
			XCTFail("Expected success but got error: \(error)")
		}

		await fulfillment(of: [requestMade], timeout: 1)
	}

	func testFetchPodcastSummariesPageIncludesCategoryIDWhenProvided() async {
		let requestMade = expectation(description: "request made")

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)

			XCTAssertEqual(url.host, "tyflopodcast.net")
			XCTAssertTrue(url.path.contains("/wp-json/wp/v2/posts"))

			let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
			let items = components.queryItems ?? []
			XCTAssertEqual(items.first(where: { $0.name == "categories" })?.value, "7")

			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (response, Data("[]".utf8))
		}

		let api = TyfloAPI(session: makeSession())
		do {
			let page = try await api.fetchPodcastSummariesPage(page: 1, perPage: 10, categoryID: 7)
			XCTAssertTrue(page.items.isEmpty)
		} catch {
			XCTFail("Expected success but got error: \(error)")
		}

		await fulfillment(of: [requestMade], timeout: 1)
	}

	func testGetCategoriesUsesPerPage100() async {
		let requestMade = expectation(description: "request made")

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)

			XCTAssertEqual(url.host, "tyflopodcast.net")
			XCTAssertTrue(url.path.contains("/wp-json/wp/v2/categories"))

			let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
			let items = components.queryItems ?? []
			XCTAssertEqual(items.first(where: { $0.name == "per_page" })?.value, "100")
			XCTAssertEqual(items.first(where: { $0.name == "orderby" })?.value, "name")
			XCTAssertEqual(items.first(where: { $0.name == "order" })?.value, "asc")
			XCTAssertEqual(items.first(where: { $0.name == "_fields" })?.value, "id,name,count")

			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (response, self.categoriesResponseData())
		}

		let api = TyfloAPI(session: makeSession())
		let categories = await api.getCategories()

		XCTAssertEqual(categories.count, 1)
		XCTAssertEqual(categories.first?.id, 10)

		await fulfillment(of: [requestMade], timeout: 1)
	}

	func testFetchPodcastCategoriesPageUsesPageAndEmbedFields() async throws {
		let requestMade = expectation(description: "request made")

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)

			XCTAssertEqual(url.host, "tyflopodcast.net")
			XCTAssertTrue(url.path.contains("/wp-json/wp/v2/categories"))

			let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
			let items = components.queryItems ?? []
			XCTAssertEqual(items.first(where: { $0.name == "per_page" })?.value, "50")
			XCTAssertEqual(items.first(where: { $0.name == "page" })?.value, "2")
			XCTAssertEqual(items.first(where: { $0.name == "orderby" })?.value, "name")
			XCTAssertEqual(items.first(where: { $0.name == "order" })?.value, "asc")
			XCTAssertEqual(items.first(where: { $0.name == "_fields" })?.value, "id,name,count")

			let response = HTTPURLResponse(
				url: url,
				statusCode: 200,
				httpVersion: nil,
				headerFields: ["X-WP-TotalPages": "3"]
			)!
			return (response, self.categoriesResponseData())
		}

		let api = TyfloAPI(session: makeSession())
		let page = try await api.fetchPodcastCategoriesPage(page: 2, perPage: 50)
		XCTAssertEqual(page.items.count, 1)
		XCTAssertEqual(page.items.first?.id, 10)
		XCTAssertEqual(page.totalPages, 3)

		await fulfillment(of: [requestMade], timeout: 1)
	}

	func testGetPodcastsForCategoryUsesCategoryId() async {
		let requestMade = expectation(description: "request made")
		let category = Category(name: "Test", id: 7, count: 0)

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)

			XCTAssertEqual(url.host, "tyflopodcast.net")
			XCTAssertTrue(url.path.contains("/wp-json/wp/v2/posts"))

			let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
			let items = components.queryItems ?? []
			XCTAssertEqual(items.first(where: { $0.name == "categories" })?.value, "7")
			XCTAssertEqual(items.first(where: { $0.name == "per_page" })?.value, "100")

			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (response, self.podcastsResponseData(ids: [42]))
		}

		let api = TyfloAPI(session: makeSession())
		let podcasts = await api.getPodcast(for: category)

		XCTAssertEqual(podcasts.count, 1)
		XCTAssertEqual(podcasts.first?.id, 42)

		await fulfillment(of: [requestMade], timeout: 1)
	}

	func testFetchArticleSummariesPageUsesPerPageAndPageParameters() async {
		let requestMade = expectation(description: "request made")

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)

			XCTAssertEqual(url.host, "tyfloswiat.pl")
			XCTAssertTrue(url.path.contains("/wp-json/wp/v2/posts"))

			let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
			let items = components.queryItems ?? []
			XCTAssertEqual(items.first(where: { $0.name == "context" })?.value, "embed")
			XCTAssertEqual(items.first(where: { $0.name == "per_page" })?.value, "10")
			XCTAssertEqual(items.first(where: { $0.name == "page" })?.value, "3")

			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (response, Data("[]".utf8))
		}

		let api = TyfloAPI(session: makeSession())
		do {
			let page = try await api.fetchArticleSummariesPage(page: 3, perPage: 10)
			XCTAssertTrue(page.items.isEmpty)
		} catch {
			XCTFail("Expected success but got error: \(error)")
		}

		await fulfillment(of: [requestMade], timeout: 1)
	}

	func testFetchArticleSummariesPageIncludesCategoryIDWhenProvided() async {
		let requestMade = expectation(description: "request made")

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)

			XCTAssertEqual(url.host, "tyfloswiat.pl")
			XCTAssertTrue(url.path.contains("/wp-json/wp/v2/posts"))

			let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
			let items = components.queryItems ?? []
			XCTAssertEqual(items.first(where: { $0.name == "categories" })?.value, "9")

			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (response, Data("[]".utf8))
		}

		let api = TyfloAPI(session: makeSession())
		do {
			let page = try await api.fetchArticleSummariesPage(page: 1, perPage: 10, categoryID: 9)
			XCTAssertTrue(page.items.isEmpty)
		} catch {
			XCTFail("Expected success but got error: \(error)")
		}

		await fulfillment(of: [requestMade], timeout: 1)
	}

	func testFetchArticleSummariesPageUsesNoStoreInMemoryCache() async throws {
		let requestMade = expectation(description: "request made")
		requestMade.expectedFulfillmentCount = 1

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)

			let response = HTTPURLResponse(
				url: url,
				statusCode: 200,
				httpVersion: nil,
				headerFields: [
					"Cache-Control": "no-store, no-cache, must-revalidate",
					"X-WP-Total": "10",
					"X-WP-TotalPages": "2",
				]
			)!
			return (response, Data("[]".utf8))
		}

		let api = TyfloAPI(session: makeSession())
		let first = try await api.fetchArticleSummariesPage(page: 3, perPage: 10)
		let second = try await api.fetchArticleSummariesPage(page: 3, perPage: 10)

		XCTAssertEqual(first.total, 10)
		XCTAssertEqual(first.totalPages, 2)
		XCTAssertEqual(second.total, 10)
		XCTAssertEqual(second.totalPages, 2)

		await fulfillment(of: [requestMade], timeout: 1)
	}

	func testNoStoreInMemoryCacheEvictsOldestWhenOverMaxEntries() async throws {
		var requestCount = 0

		StubURLProtocol.requestHandler = { request in
			requestCount += 1
			let url = try XCTUnwrap(request.url)
			let response = HTTPURLResponse(
				url: url,
				statusCode: 200,
				httpVersion: nil,
				headerFields: [
					"Cache-Control": "no-store, no-cache, must-revalidate",
					"X-WP-Total": "10",
					"X-WP-TotalPages": "2",
				]
			)!
			return (response, Data("[]".utf8))
		}

		let config = TyfloAPI.NoStoreCacheConfig(ttlSeconds: 60, maxEntries: 2, maxTotalBytes: 1024 * 1024, maxEntryBytes: 1024 * 1024)
		let api = TyfloAPI(session: makeSession(), noStoreCacheConfig: config)

		_ = try await api.fetchArticleSummariesPage(page: 1, perPage: 10)
		_ = try await api.fetchArticleSummariesPage(page: 2, perPage: 10)
		_ = try await api.fetchArticleSummariesPage(page: 3, perPage: 10)

		_ = try await api.fetchArticleSummariesPage(page: 1, perPage: 10)

		XCTAssertEqual(requestCount, 4)
	}

	func testNoStoreInMemoryCacheEvictsWhenOverMaxTotalBytes() async throws {
		var requestCount = 0
		let paddedEmptyArray = "[\(String(repeating: " ", count: 400))]".data(using: .utf8)!

		StubURLProtocol.requestHandler = { request in
			requestCount += 1
			let url = try XCTUnwrap(request.url)
			let response = HTTPURLResponse(
				url: url,
				statusCode: 200,
				httpVersion: nil,
				headerFields: [
					"Cache-Control": "no-store, no-cache, must-revalidate",
				]
			)!
			return (response, paddedEmptyArray)
		}

		let config = TyfloAPI.NoStoreCacheConfig(ttlSeconds: 60, maxEntries: 10, maxTotalBytes: 500, maxEntryBytes: 1024 * 1024)
		let api = TyfloAPI(session: makeSession(), noStoreCacheConfig: config)

		_ = try await api.fetchArticleSummariesPage(page: 1, perPage: 10)
		_ = try await api.fetchArticleSummariesPage(page: 2, perPage: 10)

		_ = try await api.fetchArticleSummariesPage(page: 1, perPage: 10)

		XCTAssertEqual(requestCount, 3)
	}

	func testFetchWPPageRetriesOnCancelledURLError() async throws {
		var requestCount = 0

		StubURLProtocol.requestHandler = { request in
			requestCount += 1
			let url = try XCTUnwrap(request.url)

			if requestCount == 1 {
				throw URLError(.cancelled)
			}

			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (response, Data("[]".utf8))
		}

		let api = TyfloAPI(session: makeSession())
		let page = try await api.fetchArticleSummariesPage(page: 1, perPage: 10)
		XCTAssertTrue(page.items.isEmpty)
		XCTAssertEqual(requestCount, 2)
	}

	func testGetArticleCategoriesUsesCorrectHost() async {
		let requestMade = expectation(description: "request made")

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)

			XCTAssertEqual(url.host, "tyfloswiat.pl")
			XCTAssertTrue(url.path.contains("/wp-json/wp/v2/categories"))

			let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
			let items = components.queryItems ?? []
			XCTAssertEqual(items.first(where: { $0.name == "per_page" })?.value, "100")
			XCTAssertEqual(items.first(where: { $0.name == "orderby" })?.value, "name")
			XCTAssertEqual(items.first(where: { $0.name == "order" })?.value, "asc")
			XCTAssertEqual(items.first(where: { $0.name == "_fields" })?.value, "id,name,count")

			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (response, self.categoriesResponseData())
		}

		let api = TyfloAPI(session: makeSession())
		let categories = await api.getArticleCategories()

		XCTAssertEqual(categories.count, 1)
		XCTAssertEqual(categories.first?.id, 10)

		await fulfillment(of: [requestMade], timeout: 1)
	}

	func testFetchArticleCategoriesPageUsesPageAndEmbedFields() async throws {
		let requestMade = expectation(description: "request made")

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)

			XCTAssertEqual(url.host, "tyfloswiat.pl")
			XCTAssertTrue(url.path.contains("/wp-json/wp/v2/categories"))

			let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
			let items = components.queryItems ?? []
			XCTAssertEqual(items.first(where: { $0.name == "per_page" })?.value, "20")
			XCTAssertEqual(items.first(where: { $0.name == "page" })?.value, "4")
			XCTAssertEqual(items.first(where: { $0.name == "orderby" })?.value, "name")
			XCTAssertEqual(items.first(where: { $0.name == "order" })?.value, "asc")
			XCTAssertEqual(items.first(where: { $0.name == "_fields" })?.value, "id,name,count")

			let response = HTTPURLResponse(
				url: url,
				statusCode: 200,
				httpVersion: nil,
				headerFields: ["X-WP-TotalPages": "10"]
			)!
			return (response, self.categoriesResponseData())
		}

		let api = TyfloAPI(session: makeSession())
		let page = try await api.fetchArticleCategoriesPage(page: 4, perPage: 20)
		XCTAssertEqual(page.items.count, 1)
		XCTAssertEqual(page.items.first?.id, 10)
		XCTAssertEqual(page.totalPages, 10)

		await fulfillment(of: [requestMade], timeout: 1)
	}

	func testGetArticlesForCategoryUsesCorrectHostAndCategoryId() async {
		let requestMade = expectation(description: "request made")
		let category = Category(name: "Test", id: 9, count: 0)

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)

			XCTAssertEqual(url.host, "tyfloswiat.pl")
			XCTAssertTrue(url.path.contains("/wp-json/wp/v2/posts"))

			let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
			let items = components.queryItems ?? []
			XCTAssertEqual(items.first(where: { $0.name == "categories" })?.value, "9")
			XCTAssertEqual(items.first(where: { $0.name == "per_page" })?.value, "100")

			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (response, self.podcastsResponseData(ids: [100]))
		}

		let api = TyfloAPI(session: makeSession())
		let articles = await api.getArticles(for: category)

		XCTAssertEqual(articles.count, 1)
		XCTAssertEqual(articles.first?.id, 100)

		await fulfillment(of: [requestMade], timeout: 1)
	}

	func testGetCommentsUsesPostIdAndPerPage100() async {
		let requestMade = expectation(description: "request made")
		let podcast = makePodcast(id: 123)

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)

			XCTAssertEqual(url.host, "tyflopodcast.net")
			XCTAssertTrue(url.path.contains("/wp-json/wp/v2/comments"))

			let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
			let items = components.queryItems ?? []
			XCTAssertEqual(items.first(where: { $0.name == "post" })?.value, "123")
			XCTAssertEqual(items.first(where: { $0.name == "per_page" })?.value, "100")

			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (response, self.commentsResponseData(postID: 123))
		}

		let api = TyfloAPI(session: makeSession())
		let comments = await api.getComments(for: podcast)

		XCTAssertEqual(comments.count, 1)
		XCTAssertEqual(comments.first?.post, 123)

		await fulfillment(of: [requestMade], timeout: 1)
	}

	func testIsTPAvailableUsesCorrectQuery() async {
		let requestMade = expectation(description: "request made")

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)

			XCTAssertEqual(url.host, "kontakt.tyflopodcast.net")
			XCTAssertEqual(request.httpMethod ?? "GET", "GET")
			XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)

			let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
			let items = components.queryItems ?? []
			XCTAssertEqual(items.first(where: { $0.name == "ac" })?.value, "current")

			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (response, self.availabilityResponseData(available: true, title: "Test"))
		}

		let api = TyfloAPI(session: makeSession())
		let (available, info) = await api.isTPAvailable()

		XCTAssertTrue(available)
		XCTAssertEqual(info.title, "Test")

		await fulfillment(of: [requestMade], timeout: 1)
	}

	func testGetRadioScheduleUsesCorrectQueryAndParsesText() async {
		let requestMade = expectation(description: "request made")

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)

			XCTAssertEqual(url.host, "kontakt.tyflopodcast.net")
			XCTAssertEqual(request.httpMethod ?? "GET", "GET")
			XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)

			let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
			let items = components.queryItems ?? []
			XCTAssertEqual(items.first(where: { $0.name == "ac" })?.value, "schedule")

			let responseBody = #"{"available":true,"text":"Line1\nLine2"}"#.data(using: .utf8)!
			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (response, responseBody)
		}

		let api = TyfloAPI(session: makeSession())
		let (success, schedule) = await api.getRadioSchedule()

		XCTAssertTrue(success)
		XCTAssertTrue(schedule.available)
		XCTAssertEqual(schedule.text, "Line1\nLine2")

		await fulfillment(of: [requestMade], timeout: 1)
	}

	func testGetRadioScheduleDoesNotUseNoStoreInMemoryCache() async {
		let requestMade = expectation(description: "request made")
		requestMade.expectedFulfillmentCount = 2

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)

			let responseBody = #"{"available":true,"text":"Test"}"#.data(using: .utf8)!
			let response = HTTPURLResponse(
				url: url,
				statusCode: 200,
				httpVersion: nil,
				headerFields: ["Cache-Control": "no-store, no-cache, must-revalidate"]
			)!
			return (response, responseBody)
		}

		let api = TyfloAPI(session: makeSession())
		_ = await api.getRadioSchedule()
		_ = await api.getRadioSchedule()

		await fulfillment(of: [requestMade], timeout: 1)
	}

	func testGetLatestPodcastsReturnsEmptyOnServerError() async {
		let requestMade = expectation(description: "request made")
		requestMade.expectedFulfillmentCount = 2

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)
			let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
			return (response, Data())
		}

		let api = TyfloAPI(session: makeSession())
		let podcasts = await api.getLatestPodcasts()
		XCTAssertTrue(podcasts.isEmpty)

		await fulfillment(of: [requestMade], timeout: 2)
	}

	func testGetLatestPodcastsReturnsEmptyOnInvalidJSON() async {
		let requestMade = expectation(description: "request made")
		requestMade.expectedFulfillmentCount = 2

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)
			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (response, Data("not-json".utf8))
		}

		let api = TyfloAPI(session: makeSession())
		let podcasts = await api.getLatestPodcasts()
		XCTAssertTrue(podcasts.isEmpty)

		await fulfillment(of: [requestMade], timeout: 2)
	}

	func testGetCategoriesReturnsEmptyOnServerError() async {
		let requestMade = expectation(description: "request made")
		requestMade.expectedFulfillmentCount = 2

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)
			let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
			return (response, Data())
		}

		let api = TyfloAPI(session: makeSession())
		let categories = await api.getCategories()
		XCTAssertTrue(categories.isEmpty)

		await fulfillment(of: [requestMade], timeout: 2)
	}

	func testGetCategoriesReturnsEmptyOnInvalidJSON() async {
		let requestMade = expectation(description: "request made")
		requestMade.expectedFulfillmentCount = 2

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)
			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (response, Data("not-json".utf8))
		}

		let api = TyfloAPI(session: makeSession())
		let categories = await api.getCategories()
		XCTAssertTrue(categories.isEmpty)

		await fulfillment(of: [requestMade], timeout: 2)
	}

	func testGetPodcastForCategoryReturnsEmptyOnServerError() async {
		let requestMade = expectation(description: "request made")
		requestMade.expectedFulfillmentCount = 2
		let category = Category(name: "Test", id: 7, count: 0)

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)
			let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
			return (response, Data())
		}

		let api = TyfloAPI(session: makeSession())
		let podcasts = await api.getPodcast(for: category)
		XCTAssertTrue(podcasts.isEmpty)

		await fulfillment(of: [requestMade], timeout: 2)
	}

	func testGetPodcastForCategoryReturnsEmptyOnInvalidJSON() async {
		let requestMade = expectation(description: "request made")
		requestMade.expectedFulfillmentCount = 2
		let category = Category(name: "Test", id: 7, count: 0)

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)
			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (response, Data("not-json".utf8))
		}

		let api = TyfloAPI(session: makeSession())
		let podcasts = await api.getPodcast(for: category)
		XCTAssertTrue(podcasts.isEmpty)

		await fulfillment(of: [requestMade], timeout: 2)
	}

	func testGetArticleCategoriesReturnsEmptyOnServerError() async {
		let requestMade = expectation(description: "request made")
		requestMade.expectedFulfillmentCount = 2

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)
			let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
			return (response, Data())
		}

		let api = TyfloAPI(session: makeSession())
		let categories = await api.getArticleCategories()
		XCTAssertTrue(categories.isEmpty)

		await fulfillment(of: [requestMade], timeout: 2)
	}

	func testGetArticleCategoriesReturnsEmptyOnInvalidJSON() async {
		let requestMade = expectation(description: "request made")
		requestMade.expectedFulfillmentCount = 2

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)
			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (response, Data("not-json".utf8))
		}

		let api = TyfloAPI(session: makeSession())
		let categories = await api.getArticleCategories()
		XCTAssertTrue(categories.isEmpty)

		await fulfillment(of: [requestMade], timeout: 2)
	}

	func testGetArticlesForCategoryReturnsEmptyOnServerError() async {
		let requestMade = expectation(description: "request made")
		requestMade.expectedFulfillmentCount = 2
		let category = Category(name: "Test", id: 9, count: 0)

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)
			let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
			return (response, Data())
		}

		let api = TyfloAPI(session: makeSession())
		let articles = await api.getArticles(for: category)
		XCTAssertTrue(articles.isEmpty)

		await fulfillment(of: [requestMade], timeout: 2)
	}

	func testGetArticlesForCategoryReturnsEmptyOnInvalidJSON() async {
		let requestMade = expectation(description: "request made")
		requestMade.expectedFulfillmentCount = 2
		let category = Category(name: "Test", id: 9, count: 0)

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)
			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (response, Data("not-json".utf8))
		}

		let api = TyfloAPI(session: makeSession())
		let articles = await api.getArticles(for: category)
		XCTAssertTrue(articles.isEmpty)

		await fulfillment(of: [requestMade], timeout: 2)
	}

	func testGetCommentsReturnsEmptyOnServerError() async {
		let requestMade = expectation(description: "request made")
		requestMade.expectedFulfillmentCount = 2
		let podcast = makePodcast(id: 123)

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)
			let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
			return (response, Data())
		}

		let api = TyfloAPI(session: makeSession())
		let comments = await api.getComments(for: podcast)
		XCTAssertTrue(comments.isEmpty)

		await fulfillment(of: [requestMade], timeout: 2)
	}

	func testGetCommentsReturnsEmptyOnInvalidJSON() async {
		let requestMade = expectation(description: "request made")
		requestMade.expectedFulfillmentCount = 2
		let podcast = makePodcast(id: 123)

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)
			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (response, Data("not-json".utf8))
		}

		let api = TyfloAPI(session: makeSession())
		let comments = await api.getComments(for: podcast)
		XCTAssertTrue(comments.isEmpty)

		await fulfillment(of: [requestMade], timeout: 2)
	}

	func testSearchReturnsEmptyOnServerError() async {
		let requestMade = expectation(description: "request made")
		requestMade.expectedFulfillmentCount = 2

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)
			let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
			return (response, Data())
		}

		let api = TyfloAPI(session: makeSession())
		let podcasts = await api.getPodcasts(for: "test")
		XCTAssertTrue(podcasts.isEmpty)

		await fulfillment(of: [requestMade], timeout: 2)
	}

	func testSearchReturnsEmptyOnInvalidJSON() async {
		let requestMade = expectation(description: "request made")
		requestMade.expectedFulfillmentCount = 2

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)
			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (response, Data("not-json".utf8))
		}

		let api = TyfloAPI(session: makeSession())
		let podcasts = await api.getPodcasts(for: "test")
		XCTAssertTrue(podcasts.isEmpty)

		await fulfillment(of: [requestMade], timeout: 2)
	}

	func testIsTPAvailableReturnsFalseOnServerError() async {
		let requestMade = expectation(description: "request made")
		requestMade.expectedFulfillmentCount = 2

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)
			let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
			return (response, Data())
		}

		let api = TyfloAPI(session: makeSession())
		let (available, info) = await api.isTPAvailable()
		XCTAssertFalse(available)
		XCTAssertFalse(info.available)
		XCTAssertNil(info.title)

		await fulfillment(of: [requestMade], timeout: 2)
	}

	func testIsTPAvailableReturnsFalseOnInvalidJSON() async {
		let requestMade = expectation(description: "request made")
		requestMade.expectedFulfillmentCount = 2

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)
			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (response, Data("not-json".utf8))
		}

		let api = TyfloAPI(session: makeSession())
		let (available, info) = await api.isTPAvailable()
		XCTAssertFalse(available)
		XCTAssertFalse(info.available)
		XCTAssertNil(info.title)

		await fulfillment(of: [requestMade], timeout: 2)
	}

	func testContactRadioPostsJSON() async {
		let requestMade = expectation(description: "request made")

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)

			XCTAssertEqual(url.host, "kontakt.tyflopodcast.net")
			XCTAssertEqual(request.httpMethod, "POST")
			XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

			let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
			let items = components.queryItems ?? []
			XCTAssertEqual(items.first(where: { $0.name == "ac" })?.value, "add")

			let body = try self.requestBodyData(from: request)
			let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
			XCTAssertEqual(json["author"] as? String, "Jan")
			XCTAssertEqual(json["comment"] as? String, "Test")

			let responseBody = #"{"author":"Jan","comment":"Test","error":null}"#.data(using: .utf8)!
			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (response, responseBody)
		}

		let api = TyfloAPI(session: makeSession())
		let (success, error) = await api.contactRadio(as: "Jan", with: "Test")

		XCTAssertTrue(success)
		XCTAssertNil(error)

		await fulfillment(of: [requestMade], timeout: 1)
	}

	func testContactRadioReturnsFalseWithErrorMessageWhenAPIReportsError() async {
		let requestMade = expectation(description: "request made")

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)

			let responseBody = #"{"author":"Jan","comment":"Test","error":"Nope"}"#.data(using: .utf8)!
			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (response, responseBody)
		}

		let api = TyfloAPI(session: makeSession())
		let (success, error) = await api.contactRadio(as: "Jan", with: "Test")

		XCTAssertFalse(success)
		XCTAssertEqual(error, "Nope")

		await fulfillment(of: [requestMade], timeout: 1)
	}

	func testContactRadioReturnsFalseOnServerError() async {
		let requestMade = expectation(description: "request made")

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)

			let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
			return (response, Data())
		}

		let api = TyfloAPI(session: makeSession())
		let (success, error) = await api.contactRadio(as: "Jan", with: "Test")

		XCTAssertFalse(success)
		XCTAssertNil(error)

		await fulfillment(of: [requestMade], timeout: 1)
	}

	func testContactRadioReturnsFalseOnInvalidJSON() async {
		let requestMade = expectation(description: "request made")

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)

			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (response, Data("not-json".utf8))
		}

		let api = TyfloAPI(session: makeSession())
		let (success, error) = await api.contactRadio(as: "Jan", with: "Test")

		XCTAssertFalse(success)
		XCTAssertNil(error)

		await fulfillment(of: [requestMade], timeout: 1)
	}

	private func podcastsResponseData(ids: [Int]) -> Data {
		let items: [[String: Any]] = ids.map { id in
			[
				"id": id,
				"date": "2026-01-20T00:59:40",
				"title": ["rendered": "Title \(id)"],
				"excerpt": ["rendered": "Excerpt \(id)"],
				"content": ["rendered": "Content \(id)"],
				"guid": ["rendered": "GUID \(id)"],
			]
		}

		return (try? JSONSerialization.data(withJSONObject: items)) ?? Data()
	}

	private func categoriesResponseData() -> Data {
		let items: [[String: Any]] = [
			[
				"name": "Test",
				"id": 10,
				"count": 5,
			],
		]
		return (try? JSONSerialization.data(withJSONObject: items)) ?? Data()
	}

	private func commentsResponseData(postID: Int) -> Data {
		let items: [[String: Any]] = [
			[
				"id": 1,
				"post": postID,
				"parent": 0,
				"author_name": "Jan",
				"content": ["rendered": "Test"],
			],
		]

		return (try? JSONSerialization.data(withJSONObject: items)) ?? Data()
	}

	private func availabilityResponseData(available: Bool, title: String?) -> Data {
		var obj: [String: Any] = ["available": available]
		if let title {
			obj["title"] = title
		}
		return (try? JSONSerialization.data(withJSONObject: obj)) ?? Data()
	}

	private func requestBodyData(from request: URLRequest) throws -> Data {
		if let body = request.httpBody {
			return body
		}

		guard let stream = request.httpBodyStream else {
			throw URLError(.badURL)
		}

		stream.open()
		defer { stream.close() }

		var data = Data()
		var buffer = [UInt8](repeating: 0, count: 1024)

		while true {
			let count = stream.read(&buffer, maxLength: buffer.count)
			if count > 0 {
				data.append(buffer, count: count)
			} else if count == 0 {
				break
			} else {
				throw stream.streamError ?? URLError(.cannotDecodeContentData)
			}
		}

		return data
	}

	func testFetchPodcastSummariesPageRetriesOnceOnServerError() async throws {
		let responseBody = #"[{"id":1,"date":"2026-01-20T00:59:40","title":{"rendered":"Test"},"excerpt":{"rendered":"Ex"},"link":"https://tyflopodcast.net/?p=1"}]"#
		var requestCount = 0

		StubURLProtocol.requestHandler = { request in
			requestCount += 1
			let url = try XCTUnwrap(request.url)

			let statusCode = requestCount == 1 ? 500 : 200
			let headers = [
				"X-WP-Total": "1",
				"X-WP-TotalPages": "1",
			]
			let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: headers)!
			return (response, Data(responseBody.utf8))
		}

		let api = TyfloAPI(session: makeSession())
		let page = try await api.fetchPodcastSummariesPage(page: 1, perPage: 1)

		XCTAssertEqual(requestCount, 2)
		XCTAssertEqual(page.items.count, 1)
		XCTAssertEqual(page.totalPages, 1)
	}

	func testContactRadioVoiceUsesAddvoiceAndMultipartContentType() async {
		let requestMade = expectation(description: "request made")

		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()
			let url = try XCTUnwrap(request.url)
			let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
			let items = components.queryItems ?? []

			XCTAssertEqual(url.host, "kontakt.tyflopodcast.net")
			XCTAssertEqual(components.path, "/json.php")
			XCTAssertEqual(items.first(where: { $0.name == "ac" })?.value, "addvoice")
			XCTAssertEqual(request.httpMethod, "POST")

			let contentType = request.value(forHTTPHeaderField: "Content-Type")
			XCTAssertNotNil(contentType)
			XCTAssertTrue(contentType?.hasPrefix("multipart/form-data; boundary=") == true)

			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (response, Data(#"{"author":"Jan","duration_ms":123}"#.utf8))
		}

		let api = TyfloAPI(session: makeSession())
		let sampleFileURL = FileManager.default.temporaryDirectory
			.appendingPathComponent("voice-\(UUID().uuidString)")
			.appendingPathExtension("m4a")
		try? Data([0x0]).write(to: sampleFileURL)
		defer { try? FileManager.default.removeItem(at: sampleFileURL) }

		let (success, _) = await api.contactRadioVoice(as: "Jan", audioFileURL: sampleFileURL, durationMs: 123)
		XCTAssertTrue(success)

		await fulfillment(of: [requestMade], timeout: 1)
	}

	private func makeSession() -> URLSession {
		let config = URLSessionConfiguration.ephemeral
		config.protocolClasses = [StubURLProtocol.self]
		return URLSession(configuration: config)
	}

	private func makePodcast(id: Int) -> Podcast {
		let title = Podcast.PodcastTitle(rendered: "Test")
		return Podcast(
			id: id,
			date: "2026-01-20T00:59:40",
			title: title,
			excerpt: title,
			content: title,
			guid: title
		)
	}
}

@MainActor
final class PushNotificationsManagerSyncTests: XCTestCase {
	override func tearDown() {
		StubURLProtocol.requestHandler = nil
		super.tearDown()
	}

	func testSyncRegistrationUsesInstallationIDWhenAPNSTokenIsMissing() async throws {
		let defaults = makeDefaults()
		defaults.set("install-1234567890123456", forKey: "push.installationID.test")

		let requestMade = expectation(description: "request made")
		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()

			let url = try XCTUnwrap(request.url)
			XCTAssertEqual(url.host, "push.test")
			XCTAssertEqual(url.path, "/api/v1/register")
			XCTAssertEqual(request.httpMethod, "POST")
			XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json; charset=utf-8")

			let body = try Self.extractBody(from: request)
			let parsed = try JSONSerialization.jsonObject(with: body) as? [String: Any]
			XCTAssertEqual(parsed?["token"] as? String, "install-1234567890123456")
			XCTAssertEqual(parsed?["env"] as? String, "ios-installation")
			let prefs = parsed?["prefs"] as? [String: Any]
			XCTAssertEqual(prefs?["podcast"] as? Bool, true)
			XCTAssertEqual(prefs?["article"] as? Bool, true)
			XCTAssertEqual(prefs?["live"] as? Bool, true)
			XCTAssertEqual(prefs?["schedule"] as? Bool, true)

			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (response, Data(#"{"ok":true}"#.utf8))
		}

		let manager = try PushNotificationsManager(
			pushServiceBaseURL: XCTUnwrap(URL(string: "https://push.test")),
			session: makeSession(),
			userDefaults: defaults,
			installationIDKey: "push.installationID.test"
		)

		await manager.syncRegistrationIfPossible(prefs: PushNotificationPreferences())
		await fulfillment(of: [requestMade], timeout: 1)
	}

	func testSyncRegistrationUsesAPNSTokenWhenAvailable() async throws {
		let defaults = makeDefaults()

		let requestMade = expectation(description: "request made")
		StubURLProtocol.requestHandler = { request in
			requestMade.fulfill()

			let body = try Self.extractBody(from: request)
			let parsed = try JSONSerialization.jsonObject(with: body) as? [String: Any]
			XCTAssertEqual(parsed?["token"] as? String, "aabb")
			XCTAssertEqual(parsed?["env"] as? String, "ios-apns")

			let url = try XCTUnwrap(request.url)
			let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (response, Data(#"{"ok":true}"#.utf8))
		}

		let manager = try PushNotificationsManager(
			pushServiceBaseURL: XCTUnwrap(URL(string: "https://push.test")),
			session: makeSession(),
			userDefaults: defaults,
			installationIDKey: "push.installationID.test"
		)

		manager.didRegisterForRemoteNotifications(deviceToken: Data([0xAA, 0xBB]))
		await fulfillment(of: [requestMade], timeout: 1)
	}

	private func makeSession() -> URLSession {
		let config = URLSessionConfiguration.ephemeral
		config.protocolClasses = [StubURLProtocol.self]
		return URLSession(configuration: config)
	}

	private func makeDefaults() -> UserDefaults {
		let suiteName = "TyflocentrumTests.PushNotificationsManagerSync.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defaults.removePersistentDomain(forName: suiteName)
		return defaults
	}

	private static func extractBody(from request: URLRequest) throws -> Data {
		if let body = request.httpBody {
			return body
		}
		if let stream = request.httpBodyStream {
			return try readAll(from: stream)
		}
		XCTFail("Request body missing (httpBody and httpBodyStream are nil).")
		return Data()
	}

	private static func readAll(from stream: InputStream) throws -> Data {
		stream.open()
		defer { stream.close() }

		var data = Data()
		var buffer = [UInt8](repeating: 0, count: 1024)
		while true {
			let readBytes = stream.read(&buffer, maxLength: buffer.count)
			if readBytes < 0 {
				throw stream.streamError ?? URLError(.cannotLoadFromNetwork)
			}
			if readBytes == 0 {
				break
			}
			data.append(buffer, count: readBytes)
		}
		return data
	}
}
