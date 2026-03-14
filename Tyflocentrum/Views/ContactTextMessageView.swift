//
//  ContactTextMessageView.swift
//  Tyflocentrum
//

import SwiftUI
import UIKit

struct ContactTextMessageView: View {
	@EnvironmentObject var api: TyfloAPI
	@Environment(\.dismiss) private var dismiss

	@StateObject private var viewModel = ContactViewModel()
	@AccessibilityFocusState private var focusedField: Field?

	private enum Field: Hashable {
		case name
		case message
	}

	var body: some View {
		let canSend = viewModel.canSend

		Form {
			Section {
				TextField("Imię", text: $viewModel.name)
					.textContentType(.name)
					.accessibilityIdentifier("contact.name")
					.accessibilityHint("Wpisz imię, które będzie widoczne przy wiadomości.")
					.accessibilityFocused($focusedField, equals: .name)

				TextEditor(text: $viewModel.message)
					.accessibilityLabel("Wiadomość")
					.accessibilityIdentifier("contact.message")
					.accessibilityHint("Wpisz treść wiadomości do redakcji.")
					.accessibilityFocused($focusedField, equals: .message)
			}

			Section {
				Button {
					Task { @MainActor in
						let didSend = await viewModel.send(using: api)
						guard didSend else { return }

						UIAccessibility.post(notification: .announcement, argument: "Wiadomość wysłana pomyślnie")
						dismiss()
					}
				} label: {
					if viewModel.isSending {
						HStack {
							ProgressView()
							Text("Wysyłanie…")
						}
						.accessibilityElement(children: .combine)
					} else {
						Text("Wyślij wiadomość")
					}
				}
				.disabled(!canSend || viewModel.isSending)
				.accessibilityHidden(!canSend && !viewModel.isSending)
				.accessibilityIdentifier("contact.send")
				.accessibilityHint(canSend ? "Wysyła wiadomość." : "Uzupełnij imię i wiadomość, aby wysłać.")
			}
		}
		.accessibilityIdentifier("contactText.form")
		.navigationTitle("Wiadomość")
		.navigationBarTitleDisplayMode(.inline)
		.alert("Błąd", isPresented: $viewModel.shouldShowError) {
			Button("OK") {}
		} message: {
			Text(viewModel.errorMessage)
		}
		.task {
			focusedField = .name
		}
		.onChange(of: viewModel.shouldShowError) { shouldShowError in
			guard !shouldShowError else { return }
			focusedField = .message
		}
	}
}
