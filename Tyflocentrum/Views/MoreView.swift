//
//  LibraryView.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 19/10/2022.
//

import Foundation
import SwiftUI

struct MoreView: View {
	var body: some View {
		NavigationView {
			VStack {
				NavigationLink {
					// Test test
					MediaPlayerView(podcast: URL(string: "https://stream-47.zeno.fm/5xyz0tc1wc9uv?zs=ulzZl64tRYaGXfASxigJWg")!)
				} label: {
					Text("Posłuchaj Tyfloradia! (niestabilne że aż boli)")
				}
			}.navigationTitle("Więcej")
		}
	}
}
