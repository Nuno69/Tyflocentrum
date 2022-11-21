//
//  ContentView.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 02/10/2022.
//
import AVFoundation
import SwiftUI

struct ContentView: View {
	@StateObject var api = TyfloAPI.shared
	var body: some View {
		TabView {
			NewsView().tabItem {
				Text("Nowości")
				Image(systemName: "newspaper")
			}.tag("News")
			PodcastCategoriesView().tabItem {
				Text("Podcasty")
				Image(systemName: "radio")
			}.tag("Podcasts")
			ArticlesCategoriesView().tabItem {
				Text("Artykuły")
				Image(systemName: "book")
			}.tag("Articles")
			SearchView().tabItem {
				Text("Szukaj")
				Image(systemName: "magnifyingglass")
			}.tag("Search")
			MoreView().tabItem {
				Text("Więcej")
				Image(systemName: "table.badge.more")
			}.tag("More")
		}.onAppear {
			do {
				try AVAudioSession.sharedInstance().setCategory(.playback)
				try AVAudioSession.sharedInstance().setActive(true)
			}
			catch {
				print("An error occurred during initialization of the audio system\n\(error.localizedDescription)")
			}
		}
	}
}
