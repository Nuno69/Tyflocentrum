import Foundation
import XCTest

@testable import Tyflocentrum

final class MultipartFormDataBuilderTests: XCTestCase {
	func testBuildBodyFileContainsFieldsAndFileBytes() throws {
		let sampleFileURL = FileManager.default.temporaryDirectory
			.appendingPathComponent("multipart-sample-\(UUID().uuidString)")
			.appendingPathExtension("m4a")
		try Data([0x01, 0x02, 0x03, 0x04]).write(to: sampleFileURL)
		defer { try? FileManager.default.removeItem(at: sampleFileURL) }

		let bodyURL = try MultipartFormDataBuilder.buildBodyFile(
			boundary: "testboundary",
			fields: [
				"author": "Jan",
				"duration_ms": "123",
			],
			file: MultipartFormDataBuilder.FilePart(
				fieldName: "audio",
				fileURL: sampleFileURL,
				fileName: "voice.m4a",
				mimeType: "audio/mp4"
			)
		)
		defer { try? FileManager.default.removeItem(at: bodyURL) }

		let body = try Data(contentsOf: bodyURL)
		assertContains(body, "--testboundary\r\nContent-Disposition: form-data; name=\"author\"\r\n\r\nJan\r\n")
		assertContains(body, "--testboundary\r\nContent-Disposition: form-data; name=\"duration_ms\"\r\n\r\n123\r\n")
		assertContains(body, "Content-Disposition: form-data; name=\"audio\"; filename=\"voice.m4a\"\r\n")
		assertContains(body, "Content-Type: audio/mp4\r\n\r\n")
		XCTAssertNotNil(body.range(of: Data([0x01, 0x02, 0x03, 0x04])))
		assertContains(body, "\r\n--testboundary--\r\n")
	}

	private func assertContains(_ data: Data, _ string: String, file: StaticString = #filePath, line: UInt = #line) {
		XCTAssertNotNil(data.range(of: Data(string.utf8)), "Expected body to contain: \(string)", file: file, line: line)
	}
}
