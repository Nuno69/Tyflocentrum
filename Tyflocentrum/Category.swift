//
//  Category.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 25/10/2022.
//

import Foundation
struct Category: Codable, Identifiable {
	var name: String
	var id: Int
	var count: Int
}
