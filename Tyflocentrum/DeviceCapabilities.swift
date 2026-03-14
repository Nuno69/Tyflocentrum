import UIKit

enum DeviceCapabilities {
	static func supportsProximityRecording(userInterfaceIdiom: UIUserInterfaceIdiom) -> Bool {
		userInterfaceIdiom == .phone
	}

	static var supportsProximityRecording: Bool {
		supportsProximityRecording(userInterfaceIdiom: UIDevice.current.userInterfaceIdiom)
	}
}
