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
		var html: NSAttributedString {
			let data = Data(rendered.utf8)
			if let attrString = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) {
				return attrString
			}
			return NSAttributedString()
		}
	}
	var id: Int
	var date: String
	var title: PodcastTitle
	var excerpt: PodcastTitle
	var content: PodcastTitle
	var guid: PodcastTitle
	
}
