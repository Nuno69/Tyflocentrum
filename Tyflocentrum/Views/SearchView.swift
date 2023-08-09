//
//  SearchView.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 19/10/2022.
//

import Foundation
import SwiftUI

struct SearchView: View {
	@EnvironmentObject var api: TyfloAPI
	@State private var podcasts = [Podcast]()
	@State private var searchText = ""
	@State private var performedSearch = false
	var searchResults: some View {
		Section {
			if performedSearch && podcasts.isEmpty {
				Text("Brak wyników wyszukiwania dla podanej frazy. Spróbuj użyć innych słów kluczowych.")
			}
			else {
				List {
					ForEach(podcasts) {item in
						NavigationLink {
							DetailedPodcastView(podcast: item)
						} label: {
							ShortPodcastView(podcast: item)
						}
					}
				}
			}
		}
	}
	var body: some View {
		NavigationView {
			Form {
				Section {
					TextField("Podaj frazę do wyszukania", text: $searchText).onSubmit {
						Task {
							podcasts = await api.getPodcasts(for: searchText)
							performedSearch = true
						}
					}
				}
				searchResults
			}.navigationTitle("Szukaj")
		}
	}
}
