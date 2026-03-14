//
//  ContactView.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 23/11/2022.
//

import Foundation
import SwiftUI

@MainActor
final class ContactViewModel: ObservableObject {
	private static let defaultMessage = "\nWysłane przy pomocy aplikacji Tyflocentrum"
	private static let nameKey = "name"
	private static let messageKey = "CurrentMSG"
	private static let fallbackErrorMessage = "Nie udało się wysłać wiadomości. Spróbuj ponownie."
	private static let fallbackVoiceErrorMessage = "Nie udało się wysłać głosówki. Spróbuj ponownie."

	@Published var name: String {
		didSet { userDefaults.set(name, forKey: Self.nameKey) }
	}

	@Published var message: String {
		didSet { userDefaults.set(message, forKey: Self.messageKey) }
	}

	@Published private(set) var isSending = false
	@Published var shouldShowError = false
	@Published var errorMessage = ""

	private let userDefaults: UserDefaults

	init(userDefaults: UserDefaults = .standard) {
		self.userDefaults = userDefaults
		name = userDefaults.string(forKey: Self.nameKey) ?? ""
		message = userDefaults.string(forKey: Self.messageKey) ?? Self.defaultMessage
		if message.isEmpty {
			message = Self.defaultMessage
		}

		#if DEBUG
			if ProcessInfo.processInfo.arguments.contains("UI_TESTING_CONTACT_MESSAGE_WHITESPACE") {
				message = " "
			}
		#endif
	}

	var canSend: Bool {
		!name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
			&& !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	func send(using api: TyfloAPI) async -> Bool {
		guard canSend else { return false }
		guard !isSending else { return false }

		isSending = true
		defer { isSending = false }

		let (success, error) = await api.contactRadio(as: name, with: message)
		guard success else {
			errorMessage = error ?? Self.fallbackErrorMessage
			shouldShowError = true
			return false
		}

		message = Self.defaultMessage
		return true
	}

	func sendVoice(using api: TyfloAPI, audioFileURL: URL, durationMs: Int) async -> Bool {
		guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
			errorMessage = "Uzupełnij imię, aby wysłać głosówkę."
			shouldShowError = true
			return false
		}
		guard !isSending else { return false }

		isSending = true
		defer { isSending = false }

		let (success, error) = await api.contactRadioVoice(as: name, audioFileURL: audioFileURL, durationMs: durationMs)
		guard success else {
			errorMessage = error ?? Self.fallbackVoiceErrorMessage
			shouldShowError = true
			return false
		}

		return true
	}
}

struct ContactView: View {
	var body: some View {
		List {
			NavigationLink {
				ContactTextMessageView()
			} label: {
				Label("Napisz wiadomość tekstową", systemImage: "square.and.pencil")
			}
			.accessibilityIdentifier("contact.menu.text")
			.accessibilityHint("Otwiera formularz wiadomości tekstowej.")

			NavigationLink {
				ContactVoiceMessageView()
			} label: {
				Label("Nagraj wiadomość głosową", systemImage: "mic")
			}
			.accessibilityIdentifier("contact.menu.voice")
			.accessibilityHint("Otwiera ekran nagrywania głosówki.")
		}
		.navigationTitle("Kontakt")
	}
}
