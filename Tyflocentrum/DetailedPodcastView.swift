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
	var body: some View {
		VStack {
			HTMLTextView(text: podcast.content.rendered)
			
			ShareLink(item: podcast.guid.rendered, message: Text("Posłuchaj audycji \(podcast.title.rendered) w serwisie Tyflopodcast!\nUdostępnione przy pomocy aplikacji Tyflocentrum"))
		}.navigationTitle(podcast.title.rendered).navigationBarTitleDisplayMode(.inline)
	}
}
