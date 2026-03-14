//
//  MoreView.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 19/10/2022.
//

import Foundation
import SwiftUI

struct MoreView: View {
	@EnvironmentObject var api: TyfloAPI
	@EnvironmentObject var audioPlayer: AudioPlayer
	@State private var shouldNavigateToContact = false
	@State private var shouldShowNoLiveAlert = false

	private func performLiveCheck() async {
		let (available, _) = await api.isTPAvailable()
		if available {
			shouldNavigateToContact = true
		} else {
			shouldShowNoLiveAlert = true
		}
	}

	var body: some View {
		NavigationStack {
			VStack(spacing: 16) {
				Spacer()

				NavigationLink {
					MediaPlayerView(
						podcast: URL(string: "https://radio.tyflopodcast.net/hls/stream.m3u8")!,
						title: "Tyfloradio",
						subtitle: nil,
						canBeLive: true
					)
				} label: {
					Label("Posłuchaj Tyfloradia", systemImage: "dot.radiowaves.left.and.right")
						.frame(maxWidth: .infinity, minHeight: 56)
				}
				.buttonStyle(.borderedProminent)
				.accessibilityHint("Otwiera odtwarzacz strumienia na żywo.")
				.accessibilityIdentifier("more.tyfloradio")

				NavigationLink {
					RadioScheduleView()
				} label: {
					Label("Sprawdź ramówkę", systemImage: "calendar")
						.frame(maxWidth: .infinity, minHeight: 56)
				}
				.buttonStyle(.bordered)
				.accessibilityHint("Pokazuje ramówkę Tyfloradia.")
				.accessibilityIdentifier("more.schedule")

				Button {
					Task {
						await performLiveCheck()
					}
				} label: {
					Label("Skontaktuj się z Tyfloradiem", systemImage: "envelope")
						.frame(maxWidth: .infinity, minHeight: 56)
				}
				.buttonStyle(.bordered)
				.accessibilityHint("Sprawdza, czy trwa audycja interaktywna i otwiera formularz kontaktu.")
				.accessibilityIdentifier("more.contactRadio")

				NavigationLink(destination: ContactView(), isActive: $shouldNavigateToContact) {
					EmptyView()
				}
				.hidden()
			}
			.padding()
			.withAppMenu()
			.navigationTitle("Tyfloradio")
			.alert("Błąd", isPresented: $shouldShowNoLiveAlert) {
				Button("OK") {}
			} message: {
				Text("Na antenie Tyfloradia nie trwa teraz żadna audycja interaktywna.")
			}
		}
	}
}
