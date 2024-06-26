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
	@State private var comments = [Comment]()
	var body: some View {
		VStack {
			HTMLTextView(text: podcast.content.rendered)
			if comments.isEmpty {
				Text("Brak komentarzy")
			}
			else {
				Text("\(comments.count) komentarzy")
			}
		}.navigationTitle("\(podcast.title.rendered) z dnia \(podcast.date)").navigationBarTitleDisplayMode(.inline).task {
			comments = await api.getComments(for: podcast)
		}.toolbar {
			ShareLink("udostępnij", item: podcast.guid.rendered, message: Text("Posłuchaj audycji \(podcast.title.rendered) w serwisie Tyflopodcast!\nUdostępnione przy pomocy aplikacji Tyflocentrum"))
			NavigationLink {
				MediaPlayerView(podcast: api.getListenableURL(for: podcast), canBeLive: false)
			} label: {
				Text("Słuchaj")
			}
		}
	}
}
