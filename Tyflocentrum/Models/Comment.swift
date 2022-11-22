//
//  Comment.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 22/11/2022.
//

import Foundation
struct Comment: Codable, Identifiable {
	struct CommentContent: Codable {
		let rendered: String
	}
	let id: Int
	let post: Int
	let parent: Int
	let authorName: String
	// let date: Date
	let content: CommentContent
}
