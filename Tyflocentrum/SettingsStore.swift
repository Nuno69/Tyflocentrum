import Foundation

enum ContentKindLabelPosition: String, CaseIterable, Identifiable {
	case before
	case after

	var id: String { rawValue }

	var title: String {
		switch self {
		case .before:
			return "Przed"
		case .after:
			return "Po"
		}
	}
}

enum PlaybackRateRememberMode: String, CaseIterable, Identifiable {
	case global
	case perEpisode

	var id: String { rawValue }

	var title: String {
		switch self {
		case .global:
			return "Globalnie"
		case .perEpisode:
			return "Dla każdego odcinka"
		}
	}
}

@MainActor
final class SettingsStore: ObservableObject {
	private let userDefaults: UserDefaults
	private let contentKindLabelPositionKey: String
	private let playbackRateRememberModeKey: String
	private let pushNotificationPreferencesKey: String

	@Published var contentKindLabelPosition: ContentKindLabelPosition = .before {
		didSet {
			userDefaults.set(contentKindLabelPosition.rawValue, forKey: contentKindLabelPositionKey)
		}
	}

	@Published var playbackRateRememberMode: PlaybackRateRememberMode = .global {
		didSet {
			userDefaults.set(playbackRateRememberMode.rawValue, forKey: playbackRateRememberModeKey)
		}
	}

	@Published var pushNotificationPreferences: PushNotificationPreferences = .init() {
		didSet {
			let encoder = JSONEncoder()
			do {
				let data = try encoder.encode(pushNotificationPreferences)
				userDefaults.set(data, forKey: pushNotificationPreferencesKey)
			} catch {
				// Avoid crashing the app because of persistence issues.
			}
		}
	}

	init(
		userDefaults: UserDefaults = .standard,
		contentKindLabelPositionKey: String = "settings.contentKindLabelPosition",
		playbackRateRememberModeKey: String = "settings.playbackRateRememberMode",
		pushNotificationPreferencesKey: String = "settings.pushNotificationPreferences.v1"
	) {
		self.userDefaults = userDefaults
		self.contentKindLabelPositionKey = contentKindLabelPositionKey
		self.playbackRateRememberModeKey = playbackRateRememberModeKey
		self.pushNotificationPreferencesKey = pushNotificationPreferencesKey

		if let rawValue = userDefaults.string(forKey: contentKindLabelPositionKey),
		   let loaded = ContentKindLabelPosition(rawValue: rawValue)
		{
			contentKindLabelPosition = loaded
		}

		if let rawValue = userDefaults.string(forKey: playbackRateRememberModeKey),
		   let loaded = PlaybackRateRememberMode(rawValue: rawValue)
		{
			playbackRateRememberMode = loaded
		}

		if let data = userDefaults.data(forKey: pushNotificationPreferencesKey) {
			let decoder = JSONDecoder()
			if let loaded = try? decoder.decode(PushNotificationPreferences.self, from: data) {
				pushNotificationPreferences = loaded
			}
		}
	}
}
