//
//  HTMLtextView.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 12/11/2022.
//

import Foundation
import SwiftUI
import UIKit
struct HTMLTextView: UIViewRepresentable {
	var text:  String
	func makeUIView(context: Context) -> UILabel {
		let label = UILabel()
		DispatchQueue.main.async {
			if let data = text.data(using: .unicode) {
				if let attrString = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) {
					label.attributedText = attrString
				}
			}
		}
		return label
	}
	func updateUIView(_ uiView: UILabel, context: Context) {
		
	}
}
