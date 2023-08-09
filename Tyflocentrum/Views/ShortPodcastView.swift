//
//  ShortPodcastView.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 25/10/2022.
//

import Foundation
import SwiftUI

struct ShortPodcastView: View {
	let podcast: Podcast
	@EnvironmentObject var api: TyfloAPI
	@State private var isPlayingFromAction = false
	var body: some View {
		HStack {
			NavigationLink(destination: MediaPlayerView(podcast: api.getListenableURL(for: podcast), canBeLive: false), isActive: $isPlayingFromAction) { EmptyView() }
			HTMLTextView(text: podcast.title.rendered).font(.largeTitle)
			HTMLTextView(text: podcast.excerpt.rendered)
		}.accessibilityElement(children: .combine).accessibilityAction(named: "Słuchaj") {
			isPlayingFromAction = true
		}
	}
}
