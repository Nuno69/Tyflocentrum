//
//  PodcastCategoriesView.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 19/10/2022.
//

import Foundation
import SwiftUI

struct PodcastCategoriesView: View {
	@EnvironmentObject var api: TyfloAPI
	@State private var categories =  [Category]()
	var body: some View {
		NavigationView {
			List {
				ForEach(categories) { item in
					NavigationLink {
						DetailedCategoryView(category: item)
					} label: {
						ShortCategoryView(category: item)
					}
				}
			}.task {
				categories = await api.getCategories()
			}.navigationTitle("Podcasty")
		}
	}
}
