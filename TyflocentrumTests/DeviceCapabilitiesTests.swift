import UIKit
import XCTest

@testable import Tyflocentrum

final class DeviceCapabilitiesTests: XCTestCase {
	func testSupportsProximityRecordingOnlyOnPhone() {
		XCTAssertTrue(DeviceCapabilities.supportsProximityRecording(userInterfaceIdiom: .phone))
		XCTAssertFalse(DeviceCapabilities.supportsProximityRecording(userInterfaceIdiom: .pad))
		XCTAssertFalse(DeviceCapabilities.supportsProximityRecording(userInterfaceIdiom: .tv))
		XCTAssertFalse(DeviceCapabilities.supportsProximityRecording(userInterfaceIdiom: .carPlay))
		if #available(iOS 14.0, *) {
			XCTAssertFalse(DeviceCapabilities.supportsProximityRecording(userInterfaceIdiom: .mac))
		}
	}
}
