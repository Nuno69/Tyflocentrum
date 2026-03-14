//
//  AccessibleTextView.swift
//  Tyflocentrum
//

import SwiftUI
import UIKit

struct AccessibleTextView: UIViewRepresentable {
	let text: String
	var textStyle: UIFont.TextStyle = .body
	var accessibilityIdentifier: String? = nil

	func makeUIView(context _: Context) -> UITextView {
		let textView = UITextView()
		textView.backgroundColor = .clear
		textView.isEditable = false
		textView.isSelectable = true
		textView.isScrollEnabled = false
		textView.textContainerInset = .zero
		textView.textContainer.lineFragmentPadding = 0
		textView.adjustsFontForContentSizeCategory = true
		textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
		textView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
		textView.accessibilityIdentifier = accessibilityIdentifier

		updateText(in: textView)
		return textView
	}

	func updateUIView(_ uiView: UITextView, context _: Context) {
		uiView.accessibilityIdentifier = accessibilityIdentifier
		updateText(in: uiView)
	}

	private func updateText(in textView: UITextView) {
		let font = UIFont.preferredFont(forTextStyle: textStyle)
		if textView.font != font {
			textView.font = font
		}
		if textView.text != text {
			textView.text = text
		}
	}
}
