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
	let podcast: Podcast
	let shouldAutoplay = false
	@State private var handle: HSTREAM = 0
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
		}.navigationTitle("Odtwarzacz").onAppear {
			handle = bass.play(url: api.getListenableURL(for: podcast))
		}.accessibilityAction(.magicTap) {
			togglePlayback()
		}
	}
}
