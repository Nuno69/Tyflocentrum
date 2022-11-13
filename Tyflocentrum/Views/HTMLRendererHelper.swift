//
//  HTMLRendererHelper.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 13/11/2022.
//

import Foundation
import SwiftUI
import WebKit
struct HTMLRendererHelper: UIViewRepresentable {
	var text: String
	func makeUIView(context: Context) -> WKWebView {
		WKWebView()
	}
	func updateUIView(_ uiView: WKWebView, context: Context) {
		uiView.loadHTMLString(text, baseURL: nil)
	}
}
