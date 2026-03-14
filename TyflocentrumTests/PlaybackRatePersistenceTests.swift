import MediaPlayer
import XCTest

@testable import Tyflocentrum

@MainActor
final class PlaybackRatePersistenceTests: XCTestCase {
	override func tearDown() {
		let nowPlaying = MPNowPlayingInfoCenter.default()
		nowPlaying.nowPlayingInfo = nil
		nowPlaying.playbackState = .stopped
		super.tearDown()
	}

	func testGlobalPlaybackRateIsRestoredOnPlay() throws {
		let defaults = makeDefaults()
		let mode: () -> PlaybackRateRememberMode = { .global }

		var audioPlayer: AudioPlayer? = AudioPlayer(userDefaults: defaults, playbackRateModeProvider: mode)
		defer {
			audioPlayer?.stop()
			audioPlayer = nil
		}

		audioPlayer?.setPlaybackRate(2.5)

		var restored: AudioPlayer? = AudioPlayer(userDefaults: defaults, playbackRateModeProvider: mode)
		defer {
			restored?.stop()
			restored = nil
		}

		let url = try makeTempAudioURL()
		restored?.play(url: url, title: nil, subtitle: nil, isLiveStream: false)
		XCTAssertEqual(restored?.playbackRate, 2.5)
	}

	func testPerEpisodePlaybackRateIsStoredSeparately() throws {
		let defaults = makeDefaults()
		let mode: () -> PlaybackRateRememberMode = { .perEpisode }

		var audioPlayer: AudioPlayer? = AudioPlayer(userDefaults: defaults, playbackRateModeProvider: mode)
		defer {
			audioPlayer?.stop()
			audioPlayer = nil
		}

		let first = try makeTempAudioURL()
		let second = try makeTempAudioURL()

		audioPlayer?.play(url: first, title: nil, subtitle: nil, isLiveStream: false)
		audioPlayer?.setPlaybackRate(2.2)
		XCTAssertEqual(audioPlayer?.playbackRate, 2.2)

		audioPlayer?.play(url: second, title: nil, subtitle: nil, isLiveStream: false)
		XCTAssertEqual(audioPlayer?.playbackRate, 1.0)

		audioPlayer?.setPlaybackRate(1.75)
		XCTAssertEqual(audioPlayer?.playbackRate, 1.75)

		audioPlayer?.play(url: first, title: nil, subtitle: nil, isLiveStream: false)
		XCTAssertEqual(audioPlayer?.playbackRate, 2.2)
	}

	func testChangingRememberModeUpdatesCurrentPlaybackRateImmediately() throws {
		let defaults = makeDefaults()

		let globalRate = 2.5
		defaults.set(Double(globalRate), forKey: "playbackRate.global")

		let url = try makeTempAudioURL()
		defaults.set(1.75, forKey: "playbackRate.\(url.absoluteString)")

		var rememberMode: PlaybackRateRememberMode = .global
		let modeProvider: () -> PlaybackRateRememberMode = { rememberMode }

		var audioPlayer: AudioPlayer? = AudioPlayer(userDefaults: defaults, playbackRateModeProvider: modeProvider)
		defer {
			audioPlayer?.stop()
			audioPlayer = nil
		}

		audioPlayer?.play(url: url, title: nil, subtitle: nil, isLiveStream: false)
		XCTAssertEqual(audioPlayer?.playbackRate, Float(globalRate))

		rememberMode = .perEpisode
		audioPlayer?.applyPlaybackRateRememberModeChange()
		XCTAssertEqual(audioPlayer?.playbackRate, 1.75)

		rememberMode = .global
		audioPlayer?.applyPlaybackRateRememberModeChange()
		XCTAssertEqual(audioPlayer?.playbackRate, Float(globalRate))

		XCTAssertEqual(defaults.double(forKey: "playbackRate.global"), Double(globalRate))
		XCTAssertEqual(defaults.double(forKey: "playbackRate.\(url.absoluteString)"), 1.75)
	}

	private func makeDefaults() -> UserDefaults {
		let suiteName = "TyflocentrumTests.PlaybackRatePersistence.\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suiteName)!
		defaults.removePersistentDomain(forName: suiteName)
		return defaults
	}

	private func makeTempAudioURL(fileExtension: String = "mp3") throws -> URL {
		let url = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString)
			.appendingPathExtension(fileExtension)
		try Data().write(to: url)
		return url
	}
}
