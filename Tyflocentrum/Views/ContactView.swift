//
//  ContactView.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 23/11/2022.
//

import Foundation
import SwiftUI
struct ContactView: View {
	@EnvironmentObject var api: TyfloAPI
	@Environment(\.dismiss) var dismiss
@AppStorage("name") private var name = ""
	@AppStorage("CurrentMSG") private var message = "\nWysłane przy pomocy aplikacji Tyflocentrum"
	@State private var shouldShowError = false
	@State private var errorMessage = ""
	func performSend() async -> Void {
		let (success, error) = await api.contactRadio(as: name, with: message)
		if !success {
			shouldShowError = true
			message = "\(error ?? "Nieznany błąd")"
		}
		message = "\nWysłane przy pomocy aplikacji TyfloCentrum"
	}
	var body: some View {
		NavigationView {
			Form {
				Section {
					TextField("Imię", text: $name)
					TextEditor(text: $message)
				}
				Section {
					Button("Wyślij") {
						Task {
							await performSend()
							UIAccessibility.post(notification: .announcement, argument: "Wiadomość wysłana pomyślnie")
							dismiss()
						}
					}.alert("Błąd", isPresented: $shouldShowError) {
						Button("OK") {}
					} message: {
						Text(errorMessage)
					}
				}.disabled(name.isEmpty || message.isEmpty)
			}.toolbar {
				Button("Anuluj") {
					dismiss()
				}
			}
		}
	}
}
