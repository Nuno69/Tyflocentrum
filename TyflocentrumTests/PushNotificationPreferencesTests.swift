import XCTest

@testable import Tyflocentrum

@MainActor
final class PushNotificationPreferencesTests: XCTestCase {
	func testDefaultsEnableAllCategories() {
		let defaults = makeDefaults()
		let settings = SettingsStore(userDefaults: defaults)
		XCTAssertEqual(
			settings.pushNotificationPreferences,
			PushNotificationPreferences(podcast: true, article: true, live: true, schedule: true)
		)
		XCTAssertTrue(settings.pushNotificationPreferences.allEnabled)
	}

	func testPreferencesArePersisted() {
		let defaults = makeDefaults()

		let first = SettingsStore(userDefaults: defaults)
		first.pushNotificationPreferences = PushNotificationPreferences(podcast: false, article: true, live: false, schedule: true)

		let restored = SettingsStore(userDefaults: defaults)
		XCTAssertEqual(
			restored.pushNotificationPreferences,
			PushNotificationPreferences(podcast: false, article: true, live: false, schedule: true)
		)
		XCTAssertFalse(restored.pushNotificationPreferences.allEnabled)
	}

	func testSetAllTogglesAllFields() {
		var prefs = PushNotificationPreferences(podcast: true, article: false, live: true, schedule: true)
		XCTAssertFalse(prefs.allEnabled)

		prefs.setAll(true)
		XCTAssertEqual(prefs, PushNotificationPreferences(podcast: true, article: true, live: true, schedule: true))
		XCTAssertTrue(prefs.allEnabled)

		prefs.setAll(false)
		XCTAssertEqual(prefs, PushNotificationPreferences(podcast: false, article: false, live: false, schedule: false))
		XCTAssertFalse(prefs.allEnabled)
	}

	private func makeDefaults() -> UserDefaults {
		let suiteName = "TyflocentrumTests.PushNotificationPreferences.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defaults.removePersistentDomain(forName: suiteName)
		return defaults
	}
}
