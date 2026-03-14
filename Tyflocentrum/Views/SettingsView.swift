import SwiftUI
import UserNotifications

struct SettingsView: View {
	@EnvironmentObject private var settings: SettingsStore
	@EnvironmentObject private var audioPlayer: AudioPlayer
	@EnvironmentObject private var pushNotifications: PushNotificationsManager

	private func pushAuthorizationTitle(_ status: UNAuthorizationStatus) -> String {
		switch status {
		case .notDetermined:
			return "Nieustawione"
		case .denied:
			return "Odmowa"
		case .authorized:
			return "Dozwolone"
		case .provisional:
			return "Tymczasowe"
		case .ephemeral:
			return "Tymczasowe (ephemeral)"
		@unknown default:
			return "Nieznane"
		}
	}

	var body: some View {
		List {
			Section("Wskazuj typ treści") {
				Picker("Pozycja", selection: $settings.contentKindLabelPosition) {
					ForEach(ContentKindLabelPosition.allCases) { position in
						Text(position.title)
							.tag(position)
					}
				}
				.pickerStyle(.segmented)
				.accessibilityLabel("Wskazuj typ treści")
				.accessibilityValue(settings.contentKindLabelPosition.title)
				.accessibilityHint("Określa, czy typ treści będzie czytany przed czy po tytule na listach.")
				.accessibilityIdentifier("settings.contentKindLabelPosition")
			}

			Section("Zapamiętaj prędkość przyspieszania") {
				Picker("Tryb", selection: $settings.playbackRateRememberMode) {
					ForEach(PlaybackRateRememberMode.allCases) { mode in
						Text(mode.title)
							.tag(mode)
					}
				}
				.pickerStyle(.segmented)
				.accessibilityLabel("Zapamiętaj prędkość przyspieszania")
				.accessibilityValue(settings.playbackRateRememberMode.title)
				.accessibilityHint("Określa, czy prędkość odtwarzania ma być wspólna, czy zapamiętywana osobno dla każdego odcinka.")
				.accessibilityIdentifier("settings.playbackRateRememberMode")
			}

			#if DEBUG
				Section("Powiadomienia push") {
					Toggle(
						"Wszystkie",
						isOn: Binding(
							get: { settings.pushNotificationPreferences.allEnabled },
							set: { enabled in
								var next = settings.pushNotificationPreferences
								next.setAll(enabled)
								settings.pushNotificationPreferences = next
							}
						)
					)
					.accessibilityHint("Włącza lub wyłącza wszystkie powiadomienia naraz.")
					.accessibilityIdentifier("settings.push.all")

					Toggle("Nowe odcinki Tyflopodcast", isOn: $settings.pushNotificationPreferences.podcast)
						.accessibilityHint("Powiadamia o nowych odcinkach w serwisie Tyflopodcast.")
						.accessibilityIdentifier("settings.push.podcast")

					Toggle("Nowe artykuły Tyfloświat", isOn: $settings.pushNotificationPreferences.article)
						.accessibilityHint("Powiadamia o nowych artykułach w serwisie Tyfloświat.")
						.accessibilityIdentifier("settings.push.article")

					Toggle("Start audycji interaktywnej Tyfloradio", isOn: $settings.pushNotificationPreferences.live)
						.accessibilityHint("Powiadamia o uruchomieniu audycji interaktywnej na żywo w Tyfloradiu.")
						.accessibilityIdentifier("settings.push.live")

					Toggle("Zmiana ramówki Tyfloradio", isOn: $settings.pushNotificationPreferences.schedule)
						.accessibilityHint("Powiadamia o zmianach w ramówce Tyfloradia.")
						.accessibilityIdentifier("settings.push.schedule")

					Text("Zgoda systemu: \(pushAuthorizationTitle(pushNotifications.authorizationStatus))")
						.accessibilityIdentifier("settings.push.status.permission")

					Text(pushNotifications.deviceTokenHex == nil ? "Token (APNs): brak" : "Token (APNs): dostępny")
						.accessibilityHint("Do prawdziwych pushy wymagany jest token z APNs.")
						.accessibilityIdentifier("settings.push.status.token")

					if let lastServerSyncAt = pushNotifications.lastServerSyncAt {
						Text("Synchronizacja z serwerem: \(lastServerSyncAt.formatted(date: .numeric, time: .standard))")
							.accessibilityIdentifier("settings.push.status.serverSyncAt")
					} else {
						Text("Synchronizacja z serwerem: brak")
							.accessibilityIdentifier("settings.push.status.serverSyncAt")
					}

					if let lastServerSyncError = pushNotifications.lastServerSyncError {
						Text("Błąd synchronizacji: \(lastServerSyncError)")
							.accessibilityIdentifier("settings.push.status.serverSyncError")
					}

					if let lastServerSyncTokenKind = pushNotifications.lastServerSyncTokenKind {
						Text("Tryb rejestracji: \(lastServerSyncTokenKind)")
							.accessibilityHint("Określa, czy aplikacja ma token APNs, czy działa w trybie testowym bez Apple Developer Program.")
							.accessibilityIdentifier("settings.push.status.serverSyncTokenKind")
					}

					if let lastRegistrationError = pushNotifications.lastRegistrationError {
						Text("Błąd rejestracji iOS: \(lastRegistrationError)")
							.accessibilityIdentifier("settings.push.status.iosRegistrationError")
					}
				}
			#endif
		}
		.onChange(of: settings.playbackRateRememberMode) { _ in
			audioPlayer.applyPlaybackRateRememberModeChange()
		}
		.navigationTitle("Ustawienia")
		.navigationBarTitleDisplayMode(.inline)
		.accessibilityIdentifier("settings.view")
	}
}
