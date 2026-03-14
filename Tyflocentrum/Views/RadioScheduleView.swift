import SwiftUI

struct RadioScheduleView: View {
	@EnvironmentObject var api: TyfloAPI

	@State private var isLoading = false
	@State private var scheduleText: String? = nil
	@State private var isAvailable = false

	@State private var shouldShowError = false
	@State private var errorMessage = ""

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				if isLoading {
					ProgressView("Ładowanie ramówki…")
						.accessibilityIdentifier("radioSchedule.loading")
				} else if let scheduleText, !scheduleText.isEmpty {
					AccessibleTextView(
						text: scheduleText,
						accessibilityIdentifier: "radioSchedule.text"
					)
					.frame(maxWidth: .infinity, alignment: .leading)
				} else if isAvailable {
					Text("Ramówka jest dostępna, ale nie zawiera treści.")
						.foregroundColor(.secondary)
						.accessibilityIdentifier("radioSchedule.empty")
				} else {
					Text("Brak dostępnej ramówki.")
						.foregroundColor(.secondary)
						.accessibilityIdentifier("radioSchedule.unavailable")
				}
			}
			.padding()
		}
		.accessibilityIdentifier("radioSchedule.view")
		.navigationTitle("Ramówka")
		.navigationBarTitleDisplayMode(.inline)
		.refreshable {
			await loadSchedule()
		}
		.task {
			await loadSchedule()
		}
		.alert("Błąd", isPresented: $shouldShowError) {
			Button("OK") {}
		} message: {
			Text(errorMessage)
		}
	}

	private func loadSchedule() async {
		guard !isLoading else { return }
		isLoading = true
		defer { isLoading = false }

		let (success, schedule) = await api.getRadioSchedule()
		isAvailable = schedule.available
		scheduleText = schedule.text?.trimmingCharacters(in: .whitespacesAndNewlines)

		guard !success else { return }
		errorMessage = schedule.error ?? "Nie udało się pobrać ramówki. Spróbuj ponownie."
		shouldShowError = true
	}
}
