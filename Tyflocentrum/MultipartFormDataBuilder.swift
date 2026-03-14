//
//  MultipartFormDataBuilder.swift
//  Tyflocentrum
//
//  Created by Codex on 27/01/2026.
//

import Foundation

enum MultipartFormDataBuilder {
	struct FilePart {
		let fieldName: String
		let fileURL: URL
		let fileName: String
		let mimeType: String
	}

	static func buildBodyFile(
		boundary: String,
		fields: [String: String],
		file: FilePart
	) throws -> URL {
		let bodyURL = FileManager.default.temporaryDirectory
			.appendingPathComponent("multipart-\(UUID().uuidString)")
			.appendingPathExtension("tmp")

		FileManager.default.createFile(atPath: bodyURL.path, contents: nil)
		let writeHandle = try FileHandle(forWritingTo: bodyURL)
		defer { writeHandle.closeFile() }

		func write(_ string: String) throws {
			guard let data = string.data(using: .utf8) else { return }
			writeHandle.write(data)
		}

		for (name, value) in fields {
			try write("--\(boundary)\r\n")
			try write("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
			try write(value)
			try write("\r\n")
		}

		try write("--\(boundary)\r\n")
		try write("Content-Disposition: form-data; name=\"\(file.fieldName)\"; filename=\"\(file.fileName)\"\r\n")
		try write("Content-Type: \(file.mimeType)\r\n\r\n")

		let readHandle = try FileHandle(forReadingFrom: file.fileURL)
		defer { readHandle.closeFile() }

		while true {
			let chunk = readHandle.readData(ofLength: 1024 * 1024)
			if chunk.isEmpty { break }
			writeHandle.write(chunk)
		}

		try write("\r\n")
		try write("--\(boundary)--\r\n")

		return bodyURL
	}
}
