//
//  DetailedArticleView.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 13/11/2022.
//

import Foundation
import SwiftUI
struct DetailedArticleView: View {
	let article: Podcast
	var body: some View {
		HTMLRendererHelper(text: article.content.rendered).navigationTitle(article.title.rendered).navigationBarTitleDisplayMode(.inline)
	}
}
