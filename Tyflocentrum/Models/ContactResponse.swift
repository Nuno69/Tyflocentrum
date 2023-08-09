//
//  ContactResponse.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 23/11/2022.
//

import Foundation
struct ContactResponse: Codable {
	let author: String
	let comment: String
	let error: String?
}
