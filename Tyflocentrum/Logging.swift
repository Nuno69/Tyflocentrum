//
//  Logging.swift
//  Tyflocentrum
//

import Foundation
import os

enum AppLog {
	private static var subsystem: String {
		Bundle.main.bundleIdentifier ?? "Tyflocentrum"
	}

	static let network = Logger(subsystem: subsystem, category: "network")
	static let persistence = Logger(subsystem: subsystem, category: "persistence")
	static let uiTests = Logger(subsystem: subsystem, category: "ui-tests")
}
