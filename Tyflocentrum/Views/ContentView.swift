//
//  ContentView.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 02/10/2022.
//
import SwiftUI

struct ContentView: View {
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
				Text("Tyfloradio")
				Image(systemName: "dot.radiowaves.left.and.right")
			}.tag("Tyfloradio")
		}
	}
}
