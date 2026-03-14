import AVFoundation
import XCTest

@testable import Tyflocentrum

@MainActor
final class VoiceMessageRecorderAudioSessionTests: XCTestCase {
	private final class FakeAudioSession: AudioSessionProtocol {
		enum Event: Equatable {
			case setCategory(AVAudioSession.Category, AVAudioSession.Mode, AVAudioSession.CategoryOptions)
			case setAllowHaptics(Bool)
			case setActive(Bool, AVAudioSession.SetActiveOptions)
			case overrideOutput(AVAudioSession.PortOverride)
		}

		var category: AVAudioSession.Category = .ambient
		var mode: AVAudioSession.Mode = .default

		private(set) var events: [Event] = []

		func setCategory(_ category: AVAudioSession.Category, mode: AVAudioSession.Mode, options: AVAudioSession.CategoryOptions) throws {
			self.category = category
			self.mode = mode
			events.append(.setCategory(category, mode, options))
		}

		func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws {
			events.append(.setActive(active, options))
		}

		func overrideOutputAudioPort(_ portOverride: AVAudioSession.PortOverride) throws {
			events.append(.overrideOutput(portOverride))
		}

		func requestRecordPermission(_ response: @escaping (Bool) -> Void) {
			response(true)
		}

		func setAllowHapticsAndSystemSoundsDuringRecording(_ inValue: Bool) throws {
			events.append(.setAllowHaptics(inValue))
		}
	}

	func testConfigureAudioSessionForRecordingAllowsHapticsDuringRecording() throws {
		let session = FakeAudioSession()

		try VoiceMessageRecorder.configureAudioSessionForRecording(session)

		guard case let .setCategory(category, mode, options) = session.events.first else {
			return XCTFail("Expected setCategory first, got: \(session.events)")
		}
		XCTAssertEqual(category, .playAndRecord)
		XCTAssertEqual(mode, .spokenAudio)
		XCTAssertTrue(options.contains(.defaultToSpeaker))
		XCTAssertTrue(options.contains(.allowBluetooth))

		XCTAssertEqual(session.events.count, 3)
		XCTAssertEqual(session.events[1], .setAllowHaptics(true))
		guard case let .setActive(active, _) = session.events[2] else {
			return XCTFail("Expected setActive last, got: \(session.events)")
		}
		XCTAssertTrue(active)
	}
}
