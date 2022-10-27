//
//  Podcast.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 24/10/2022.
//

import Foundation
struct Podcast: Codable, Identifiable {
	struct PodcastTitle: Codable {
		var rendered: String
	}
	var id: Int
	var date: String
	var title: PodcastTitle
	var excerpt: PodcastTitle
	
}
