//
//  ArticlesView.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 19/10/2022.
//

import Foundation
import SwiftUI

struct ArticlesCategoriesView: View {
	@EnvironmentObject var api: TyfloAPI
	@State private var categories = [Category]()
	var body: some View {
		NavigationView {
			List {
				ForEach(categories) {item in
					ShortCategoryView(category: item)
				}
			}.task {
				categories = await api.getArticleCategories()
			}.navigationTitle("Artykuły")
		}
	}
}
