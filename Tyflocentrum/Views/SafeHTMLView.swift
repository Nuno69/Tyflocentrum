//
//  SafeHTMLView.swift
//  Tyflocentrum
//

import SwiftUI
import UIKit
import WebKit

struct SafeHTMLView: UIViewRepresentable {
	@Environment(\.dynamicTypeSize) private var dynamicTypeSize

	let htmlBody: String
	let baseURL: URL?
	let accessibilityIdentifier: String?

	init(htmlBody: String, baseURL: URL? = nil, accessibilityIdentifier: String? = nil) {
		self.htmlBody = htmlBody
		self.baseURL = baseURL
		self.accessibilityIdentifier = accessibilityIdentifier
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(allowedHost: baseURL?.host)
	}

	func makeUIView(context: Context) -> WKWebView {
		let configuration = WKWebViewConfiguration()
		configuration.websiteDataStore = .nonPersistent()
		configuration.defaultWebpagePreferences.allowsContentJavaScript = false

		let webView = WKWebView(frame: .zero, configuration: configuration)
		webView.navigationDelegate = context.coordinator
		webView.uiDelegate = context.coordinator
		webView.isOpaque = false
		webView.backgroundColor = .clear
		webView.scrollView.backgroundColor = .clear
		webView.allowsBackForwardNavigationGestures = false
		webView.allowsLinkPreview = false
		webView.accessibilityIdentifier = accessibilityIdentifier

		if #available(iOS 15.0, *) {
			webView.underPageBackgroundColor = .clear
		}

		return webView
	}

	func updateUIView(_ uiView: WKWebView, context: Context) {
		uiView.accessibilityIdentifier = accessibilityIdentifier
		context.coordinator.allowedHost = baseURL?.host

		let optimizedBody = Self.optimizeHTMLBody(htmlBody)
		let document = Self.makeDocument(body: optimizedBody, fontSize: UIFont.preferredFont(forTextStyle: .body).pointSize)
		guard context.coordinator.lastLoadedHTML != document else { return }

		context.coordinator.lastLoadedHTML = document
		uiView.loadHTMLString(document, baseURL: baseURL)
	}

	static func optimizeHTMLBody(_ body: String) -> String {
		// Reduce memory/CPU spikes for large articles by hinting the engine to defer image loading/decoding.
		// (No JavaScript needed; SafeHTMLView disables JS.)
		var result = body
		result = result.replacingOccurrences(
			of: "(?i)<img(?![^>]*\\bloading=)",
			with: "<img loading=\"lazy\"",
			options: .regularExpression
		)
		result = result.replacingOccurrences(
			of: "(?i)<img(?![^>]*\\bdecoding=)",
			with: "<img decoding=\"async\"",
			options: .regularExpression
		)
		result = result.replacingOccurrences(
			of: "(?i)<img(?![^>]*\\bfetchpriority=)",
			with: "<img fetchpriority=\"low\"",
			options: .regularExpression
		)
		return result
	}

	static func makeDocument(body: String, fontSize: CGFloat, languageCode: String = "pl") -> String {
		"""
		<!doctype html>
		<html lang="\(languageCode)">
		<head>
		  <meta charset="utf-8">
		  <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
		  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src https: data:; style-src 'unsafe-inline'; frame-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'">
		  <style>
			:root { color-scheme: light dark; }
			body {
			  font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', Helvetica, Arial, sans-serif;
			  font-size: \(fontSize)px;
			  line-height: 1.45;
			  margin: 0;
			  padding: 16px;
			  overflow-wrap: anywhere;
			  -webkit-text-size-adjust: 100%;
			}
			img { max-width: 100%; height: auto; }
			table { width: 100%; border-collapse: collapse; display: block; overflow-x: auto; }
			th, td { border: 1px solid rgba(127, 127, 127, 0.35); padding: 0.4rem; vertical-align: top; }
			pre, code {
			  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', 'Courier New', monospace;
			  white-space: pre-wrap;
			}
		  </style>
		</head>
		<body>
		  \(body)
		</body>
		</html>
		"""
	}

	static func isAllowedWebViewScheme(_ scheme: String?) -> Bool {
		switch scheme?.lowercased() {
		case "http", "https", "about":
			return true
		default:
			return false
		}
	}

	static func isAllowedExternalScheme(_ scheme: String?) -> Bool {
		switch scheme?.lowercased() {
		case "http", "https", "mailto", "tel":
			return true
		default:
			return false
		}
	}

	static func isAllowedMainFrameURL(_ url: URL, allowedHost: String?) -> Bool {
		switch url.scheme?.lowercased() {
		case "about":
			return true
		case "http", "https":
			guard let allowedHost else { return false }
			return url.host == allowedHost
		default:
			return false
		}
	}

	final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
		var lastLoadedHTML: String?
		var allowedHost: String?

		init(allowedHost: String? = nil) {
			self.allowedHost = allowedHost
		}

		func webView(
			_: WKWebView,
			decidePolicyFor navigationAction: WKNavigationAction,
			decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
		) {
			guard let url = navigationAction.request.url else {
				decisionHandler(.cancel)
				return
			}

			if navigationAction.navigationType == .linkActivated {
				openExternally(url)
				decisionHandler(.cancel)
				return
			}

			let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
			if isMainFrame {
				decisionHandler(SafeHTMLView.isAllowedMainFrameURL(url, allowedHost: allowedHost) ? .allow : .cancel)
				return
			}

			if SafeHTMLView.isAllowedWebViewScheme(url.scheme) {
				decisionHandler(.allow)
			} else {
				decisionHandler(.cancel)
			}
		}

		func webView(
			_: WKWebView,
			createWebViewWith _: WKWebViewConfiguration,
			for navigationAction: WKNavigationAction,
			windowFeatures _: WKWindowFeatures
		) -> WKWebView? {
			if let url = navigationAction.request.url {
				openExternally(url)
			}
			return nil
		}

		private func openExternally(_ url: URL) {
			guard SafeHTMLView.isAllowedExternalScheme(url.scheme) else { return }
			DispatchQueue.main.async {
				UIApplication.shared.open(url)
			}
		}
	}
}
