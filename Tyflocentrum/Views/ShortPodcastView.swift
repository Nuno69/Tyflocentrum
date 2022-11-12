//
//  ShortPodcastView.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 25/10/2022.
//

import Foundation
import SwiftUI

struct ShortPodcastView: View {
	let podcast: Podcast
	var body: some View {
		HStack {
			HTMLTextView(text: podcast.title.rendered).font(.largeTitle)
			HTMLTextView(text: podcast.excerpt.rendered)
		}.accessibilityElement(children: .combine)
	}
}
