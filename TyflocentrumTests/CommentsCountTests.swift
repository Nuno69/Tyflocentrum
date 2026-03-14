import Foundation
import XCTest

@testable import Tyflocentrum

final class CommentsCountTests: XCTestCase {
	override func tearDown() {
		StubURLProtocol.requestHandler = nil
		super.tearDown()
	}

	func testFetchCommentsCountUsesXWPTotalHeader() async throws {
		StubURLProtocol.requestHandler = { request in
			let url = try XCTUnwrap(request.url)

			XCTAssertEqual(url.host, "tyflopodcast.net")
			XCTAssertTrue(url.path.contains("/wp-json/wp/v2/comments"))

			let response = HTTPURLResponse(
				url: url,
				statusCode: 200,
				httpVersion: nil,
				headerFields: [
					"X-WP-Total": "12",
					"X-WP-TotalPages": "12",
				]
			)!

			let payload = #"""
			[{"id":1,"post":123,"parent":0,"author_name":"Test","content":{"rendered":"<p>Hi</p>"}}]
			"""#.data(using: .utf8) ?? Data()

			return (response, payload)
		}

		let api = TyfloAPI(session: makeSession())
		let count = try await api.fetchCommentsCount(forPostID: 123)
		XCTAssertEqual(count, 12)
	}

	private func makeSession() -> URLSession {
		let config = URLSessionConfiguration.ephemeral
		config.protocolClasses = [StubURLProtocol.self]
		return URLSession(configuration: config)
	}
}
