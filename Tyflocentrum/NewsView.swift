//
//  NewsView.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 17/10/2022.
//

import Foundation
import SwiftUI

struct NewsView: View {
	@EnvironmentObject var api: TyfloAPI
	@State private var podcasts = [Podcast]()
	var body: some View {
		NavigationView {
			VStack {
				List {
					ForEach(podcasts) {item in
						NavigationLink {
							DetailedPodcastView(podcast: item)
						} label: {
							ShortPodcastView(podcast: item)
						}
					}
				}					}.refreshable {
					podcasts.removeAll(keepingCapacity: true)
					await podcasts = api.getLatestPodcasts()
				}.task {
					await podcasts = api.getLatestPodcasts()
				}.navigationTitle("nowości")
		}
	}
}
