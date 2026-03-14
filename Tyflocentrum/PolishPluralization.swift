import Foundation

enum PolishPluralization {
	static func nounForm(for count: Int, singular: String, few: String, many: String) -> String {
		guard count != 1 else { return singular }

		let lastTwo = abs(count) % 100
		if (12 ... 14).contains(lastTwo) {
			return many
		}

		switch abs(count) % 10 {
		case 2, 3, 4:
			return few
		default:
			return many
		}
	}
}
