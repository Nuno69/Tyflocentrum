//
//  DetailedArticleCategoryView.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 12/11/2022.
//

import Foundation
import SwiftUI
struct DetailedArticleCategoryView: View {
	let category: Category
	@State private var articles = [Podcast]()
	@EnvironmentObject var api: TyfloAPI
	var body: some View {
		List {
			ForEach(articles) {item in
				NavigationLink {
					DetailedArticleView(article: item)
				} label: {
					ShortPodcastView(podcast: item)
				}
			}
		}.task {
			articles = await api.getArticles(for: category)
		}.navigationTitle(category.name).navigationBarTitleDisplayMode(.inline)
	}
}
