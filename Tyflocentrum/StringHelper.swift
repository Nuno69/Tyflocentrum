//
//  StringHelper.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 17/11/2022.
//

import Foundation
extension String {
	var pointer: UnsafeRawPointer {
		let string = self as NSString
		// Force unwrap cause we always can get a pointer from a string.
		return UnsafeRawPointer(LPVOID(mutating: string.utf8String))!
	}
}
