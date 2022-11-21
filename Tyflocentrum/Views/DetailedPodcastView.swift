//
//  DetailedPodcastView.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 27/10/2022.
//

import Foundation
import SwiftUI

struct DetailedPodcastView: View {
	let podcast: Podcast
	@EnvironmentObject var api: TyfloAPI
	@EnvironmentObject var bass: BassHelper
	var body: some View {
		VStack {
			HTMLTextView(text: podcast.content.rendered)
			HStack(spacing: 20) {
				ShareLink(item: podcast.guid.rendered, message: Text("Posłuchaj audycji \(podcast.title.rendered) w serwisie Tyflopodcast!\nUdostępnione przy pomocy aplikacji Tyflocentrum"))
				NavigationLink {
					MediaPlayerView(podcast: podcast)
				} label: {
					Text("Słuchaj")
				}
			}
		}.navigationTitle(podcast.title.rendered).navigationBarTitleDisplayMode(.inline)
		
	}
}
