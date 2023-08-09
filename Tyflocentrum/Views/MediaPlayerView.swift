//
//  MediaPlayerView.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 19/11/2022.
//

import Foundation
import SwiftUI
struct MediaPlayerView: View {
	@EnvironmentObject var api: TyfloAPI
	@EnvironmentObject var bass: BassHelper
	let podcast: URL
	let shouldAutoplay = false
	let canBeLive: Bool
	@State private var handle: HSTREAM = 0
	@State private var shouldShowContactForm = false
	@State private var shouldShowNoLiveAlert = false
	func performLiveCheck() async -> Void{
		let (available, _) = await api.isTPAvailable()
		if available {
			shouldShowContactForm = true
		}
		else {
			shouldShowNoLiveAlert = true
		}
	}
	func togglePlayback() {
		if bass.isPlaying {
			bass.pause(handle)
		}
		else {
			bass.resume(handle)
		}
	}
	var body: some View {
		HStack(alignment: .center, spacing: 20) {
			Spacer()
			Button {
				togglePlayback()
			} label: {
				Image(systemName: bass.isPlaying ? "pause.circle.fill" : "play.circle.fill").font(.title).imageScale(.large)
			}.accessibilityLabel(bass.isPlaying ? "Pauza" : "Odtwarzaj")
			if canBeLive {
				Button("Skontaktuj się z radiem") {
					Task {
						await performLiveCheck()
					}
				}.alert("Błąd", isPresented: $shouldShowNoLiveAlert) {
					Button("OK"){}
				} message: {
					Text("Na antenie Tyfloradia nie trwa teraz żadna audycja interaktywna.")
				}.sheet(isPresented: $shouldShowContactForm) {
					ContactView()
				}
			}
		}.navigationTitle("Odtwarzacz").onAppear {
			Task {
				handle = bass.play(url: podcast)
			}
		}.accessibilityAction(.magicTap) {
			togglePlayback()
		}
	}
}
