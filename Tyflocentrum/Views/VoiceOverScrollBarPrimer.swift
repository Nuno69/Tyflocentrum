//
//  VoiceOverScrollBarPrimer.swift
//  Tyflocentrum
//

import SwiftUI
import UIKit

/// Ensures VoiceOver users can access the system scroll bar immediately (without first scrolling).
///
/// This performs a tiny scroll “nudge” once when `shouldPrime` changes from `false` to `true`.
struct VoiceOverScrollBarPrimer: UIViewRepresentable {
	let shouldPrime: Bool
	let targetIdentifier: String?

	init(shouldPrime: Bool, targetIdentifier: String? = nil) {
		self.shouldPrime = shouldPrime
		self.targetIdentifier = targetIdentifier
	}

	func makeCoordinator() -> Coordinator {
		Coordinator()
	}

	func makeUIView(context _: Context) -> UIView {
		VoiceOverScrollBarPrimerHostView(targetIdentifier: targetIdentifier)
	}

	func updateUIView(_ uiView: UIView, context: Context) {
		context.coordinator.update(uiView: uiView, shouldPrime: shouldPrime)
	}

	final class Coordinator {
		private var lastShouldPrime = false
		private var primeGeneration = 0

		func update(uiView: UIView, shouldPrime: Bool) {
			defer { lastShouldPrime = shouldPrime }
			guard shouldPrime, !lastShouldPrime else { return }
			guard UIAccessibility.isVoiceOverRunning else { return }
			guard !ProcessInfo.processInfo.arguments.contains("UI_TESTING") else { return }

			primeGeneration += 1
			let generation = primeGeneration
			attemptPrime(uiView: uiView, generation: generation, remainingAttempts: 25)
		}

		private func attemptPrime(uiView: UIView, generation: Int, remainingAttempts: Int) {
			guard remainingAttempts > 0 else { return }

			DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self, weak uiView] in
				guard let self else { return }
				guard generation == self.primeGeneration else { return }
				guard let uiView else { return }

				guard UIAccessibility.isVoiceOverRunning else { return }
				guard !ProcessInfo.processInfo.arguments.contains("UI_TESTING") else { return }

				guard let scrollView = uiView.findTargetScrollView() else {
					self.attemptPrime(uiView: uiView, generation: generation, remainingAttempts: remainingAttempts - 1)
					return
				}

				guard scrollView.window != nil else {
					self.attemptPrime(uiView: uiView, generation: generation, remainingAttempts: remainingAttempts - 1)
					return
				}

				scrollView.showsVerticalScrollIndicator = true
				scrollView.layoutIfNeeded()
				scrollView.superview?.layoutIfNeeded()

				let topOffsetY = -scrollView.adjustedContentInset.top
				let bottomOffsetY = scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom
				let maxOffsetY = max(topOffsetY, bottomOffsetY)
				guard maxOffsetY > topOffsetY + 1 else {
					self.attemptPrime(uiView: uiView, generation: generation, remainingAttempts: remainingAttempts - 1)
					return
				}

				guard !scrollView.isDragging, !scrollView.isDecelerating, !scrollView.isTracking else { return }

				let originalOffset = scrollView.contentOffset
				guard originalOffset.y <= topOffsetY + 0.5 else { return }

				let available = maxOffsetY - topOffsetY
				let step = min(max(available * 0.10, 24), 80)
				let firstY = min(topOffsetY + step, maxOffsetY)
				let secondY = min(topOffsetY + step * 2, maxOffsetY)

				UIView.performWithoutAnimation {
					scrollView.setContentOffset(CGPoint(x: originalOffset.x, y: firstY), animated: false)
					scrollView.flashScrollIndicators()
				}

				DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
					UIView.performWithoutAnimation {
						scrollView.setContentOffset(CGPoint(x: originalOffset.x, y: secondY), animated: false)
						scrollView.flashScrollIndicators()
					}
				}

				DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
					UIView.performWithoutAnimation {
						scrollView.setContentOffset(originalOffset, animated: false)
						scrollView.flashScrollIndicators()
					}
				}
			}
		}
	}
}

private extension UIView {
	func findTargetScrollView() -> UIScrollView? {
		let identifier = (self as? VoiceOverScrollBarPrimerHostView)?.targetIdentifier
		let rootView: UIView = window ?? self

		let allScrollViews = rootView.allScrollViews()
			.filter { scrollView in
				guard scrollView.alpha > 0.01, !scrollView.isHidden else { return false }
				guard scrollView.isScrollEnabled else { return false }
				return true
			}

		if let identifier, let matched = allScrollViews.first(where: { $0.accessibilityIdentifier == identifier }) {
			return matched
		}

		let hostRect = convert(bounds, to: rootView)

		var bestScrollView: UIScrollView?
		var bestScore: CGFloat = -1
		for scrollView in allScrollViews {
			let scrollRect = scrollView.convert(scrollView.bounds, to: rootView)
			let intersection = hostRect.intersection(scrollRect)
			guard !intersection.isNull else { continue }

			// Prefer scroll views that are actually vertically scrollable.
			let topOffsetY = -scrollView.adjustedContentInset.top
			let bottomOffsetY = scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom
			let canScroll = bottomOffsetY > topOffsetY + 1

			var score = intersection.width * intersection.height
			if canScroll {
				score *= 2
			}

			if score > bestScore {
				bestScore = score
				bestScrollView = scrollView
			}
		}

		return bestScrollView
	}

	func allScrollViews() -> [UIScrollView] {
		var result: [UIScrollView] = []
		collectScrollViews(into: &result)
		return result
	}

	private func collectScrollViews(into result: inout [UIScrollView]) {
		if let scrollView = self as? UIScrollView {
			result.append(scrollView)
		}

		for subview in subviews {
			subview.collectScrollViews(into: &result)
		}
	}
}

private final class VoiceOverScrollBarPrimerHostView: UIView {
	let targetIdentifier: String?

	init(targetIdentifier: String?) {
		self.targetIdentifier = targetIdentifier
		super.init(frame: .zero)
	}

	@available(*, unavailable)
	required init?(coder _: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
