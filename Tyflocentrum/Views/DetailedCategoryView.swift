//
//  DetailedCategoryView.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 10/11/2022.
//

import SwiftUI

struct DetailedCategoryView: View {
	let category: Category
	@EnvironmentObject var api: TyfloAPI
	@State private var podcasts = [Podcast]()
	var body: some View {
		List {
			ForEach(podcasts) {item in
				NavigationLink {
					DetailedPodcastView(podcast: item)
				} label: {
					ShortPodcastView(podcast: item)
				}
			}
		}.task {
			podcasts = await api.getPodcast(for: category)
		}.navigationTitle(category.name).navigationBarTitleDisplayMode(.inline)
	}
}
