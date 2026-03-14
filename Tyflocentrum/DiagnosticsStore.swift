import Foundation
import UIKit

@MainActor
final class DiagnosticsStore: ObservableObject {
	struct Entry: Identifiable {
		let id = UUID()
		let timestamp: Date
		let message: String
	}

	private let userDefaults: UserDefaults
	private let enabledKey: String
	private let maxEntries: Int

	@Published var isEnabled: Bool {
		didSet {
			userDefaults.set(isEnabled, forKey: enabledKey)
		}
	}

	@Published private(set) var entries: [Entry] = []

	init(
		userDefaults: UserDefaults = .standard,
		enabledKey: String = "diagnostics.enabled",
		maxEntries: Int = 2000
	) {
		self.userDefaults = userDefaults
		self.enabledKey = enabledKey
		self.maxEntries = max(100, maxEntries)
		isEnabled = userDefaults.bool(forKey: enabledKey)
	}

	func log(_ message: String) {
		guard isEnabled else { return }

		let entry = Entry(timestamp: Date(), message: message)
		entries.append(entry)

		if entries.count > maxEntries {
			entries.removeFirst(entries.count - maxEntries)
		}
	}

	func clear() {
		entries = []
	}

	func exportText() -> String {
		let headerLines = [
			"Tyflocentrum — log diagnostyczny",
			"Data: \(Self.timestampFormatter.string(from: Date()))",
			"Aplikacja: \(Self.appVersionString())",
			"iOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
			"Urządzenie: \(UIDevice.current.model)",
			"VoiceOver: \(UIAccessibility.isVoiceOverRunning ? "włączony" : "wyłączony")",
			"Wpisy: \(entries.count)",
		]

		let bodyLines = entries.map { entry in
			"[\(Self.timestampFormatter.string(from: entry.timestamp))] \(entry.message)"
		}

		return (headerLines + [""] + bodyLines).joined(separator: "\n")
	}

	private static let timestampFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
		return formatter
	}()

	private static func appVersionString() -> String {
		let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
		let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String

		switch (version?.trimmingCharacters(in: .whitespacesAndNewlines), build?.trimmingCharacters(in: .whitespacesAndNewlines)) {
		case let (v?, b?) where !v.isEmpty && !b.isEmpty:
			return "\(v) (\(b))"
		case let (v?, _) where !v.isEmpty:
			return v
		case let (_, b?) where !b.isEmpty:
			return b
		default:
			return "nieznana"
		}
	}
}
