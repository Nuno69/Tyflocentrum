//
//  AudioPlayer.swift
//  Tyflocentrum
//
//  Replaced BASS-based playback with AVPlayer.
//

import AVFoundation
import Foundation
import MediaPlayer

protocol RemoteCommandCenterProtocol {
	var play: RemoteCommandProtocol { get }
	var pause: RemoteCommandProtocol { get }
	var togglePlayPause: RemoteCommandProtocol { get }
	var skipForward: SkipIntervalRemoteCommandProtocol { get }
	var skipBackward: SkipIntervalRemoteCommandProtocol { get }
	var changePlaybackPosition: ChangePlaybackPositionRemoteCommandProtocol { get }
	var changePlaybackRate: ChangePlaybackRateRemoteCommandProtocol { get }
}

protocol RemoteCommandProtocol: AnyObject {
	var isEnabled: Bool { get set }
	func addHandler(_ handler: @escaping () -> Bool)
	func removeAllHandlers()
}

protocol SkipIntervalRemoteCommandProtocol: AnyObject {
	var isEnabled: Bool { get set }
	var preferredIntervals: [NSNumber] { get set }
	func addHandler(_ handler: @escaping (Double) -> Bool)
	func removeAllHandlers()
}

protocol ChangePlaybackPositionRemoteCommandProtocol: AnyObject {
	var isEnabled: Bool { get set }
	func addHandler(_ handler: @escaping (TimeInterval) -> Bool)
	func removeAllHandlers()
}

protocol ChangePlaybackRateRemoteCommandProtocol: AnyObject {
	var isEnabled: Bool { get set }
	func addHandler(_ handler: @escaping (Float) -> Bool)
	func removeAllHandlers()
}

enum RemoteCommandWiring {
	static let defaultSkipInterval: Double = 30

	static func install(
		center: RemoteCommandCenterProtocol,
		play: @escaping () -> Bool,
		pause: @escaping () -> Bool,
		togglePlayPause: @escaping () -> Bool,
		skipForward: @escaping (Double) -> Bool,
		skipBackward: @escaping (Double) -> Bool,
		changePlaybackPosition: @escaping (TimeInterval) -> Bool,
		changePlaybackRate: @escaping (Float) -> Bool
	) {
		center.play.addHandler(play)
		center.pause.addHandler(pause)
		center.togglePlayPause.addHandler(togglePlayPause)

		center.skipForward.preferredIntervals = [NSNumber(value: defaultSkipInterval)]
		center.skipForward.addHandler(skipForward)

		center.skipBackward.preferredIntervals = [NSNumber(value: defaultSkipInterval)]
		center.skipBackward.addHandler(skipBackward)

		center.changePlaybackPosition.addHandler(changePlaybackPosition)
		center.changePlaybackRate.addHandler(changePlaybackRate)

		center.play.isEnabled = true
		center.pause.isEnabled = true
		center.togglePlayPause.isEnabled = true
	}
}

final class SystemRemoteCommandCenter: RemoteCommandCenterProtocol {
	private let commandCenter: MPRemoteCommandCenter

	init(commandCenter: MPRemoteCommandCenter = .shared()) {
		self.commandCenter = commandCenter
	}

	var play: RemoteCommandProtocol { SystemRemoteCommand(command: commandCenter.playCommand) }
	var pause: RemoteCommandProtocol { SystemRemoteCommand(command: commandCenter.pauseCommand) }
	var togglePlayPause: RemoteCommandProtocol { SystemRemoteCommand(command: commandCenter.togglePlayPauseCommand) }
	var skipForward: SkipIntervalRemoteCommandProtocol { SystemSkipIntervalRemoteCommand(command: commandCenter.skipForwardCommand) }
	var skipBackward: SkipIntervalRemoteCommandProtocol { SystemSkipIntervalRemoteCommand(command: commandCenter.skipBackwardCommand) }
	var changePlaybackPosition: ChangePlaybackPositionRemoteCommandProtocol { SystemChangePlaybackPositionRemoteCommand(command: commandCenter.changePlaybackPositionCommand) }
	var changePlaybackRate: ChangePlaybackRateRemoteCommandProtocol { SystemChangePlaybackRateRemoteCommand(command: commandCenter.changePlaybackRateCommand) }
}

private final class SystemRemoteCommand: RemoteCommandProtocol {
	private let command: MPRemoteCommand

	init(command: MPRemoteCommand) {
		self.command = command
	}

	var isEnabled: Bool {
		get { command.isEnabled }
		set { command.isEnabled = newValue }
	}

	func addHandler(_ handler: @escaping () -> Bool) {
		command.addTarget { _ in
			handler() ? .success : .commandFailed
		}
	}

	func removeAllHandlers() {
		command.removeTarget(nil)
	}
}

private final class SystemSkipIntervalRemoteCommand: SkipIntervalRemoteCommandProtocol {
	private let command: MPSkipIntervalCommand

	init(command: MPSkipIntervalCommand) {
		self.command = command
	}

	var isEnabled: Bool {
		get { command.isEnabled }
		set { command.isEnabled = newValue }
	}

	var preferredIntervals: [NSNumber] {
		get { command.preferredIntervals }
		set { command.preferredIntervals = newValue }
	}

	func addHandler(_ handler: @escaping (Double) -> Bool) {
		command.addTarget { event in
			guard let event = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
			return handler(event.interval) ? .success : .commandFailed
		}
	}

	func removeAllHandlers() {
		command.removeTarget(nil)
	}
}

private final class SystemChangePlaybackPositionRemoteCommand: ChangePlaybackPositionRemoteCommandProtocol {
	private let command: MPChangePlaybackPositionCommand

	init(command: MPChangePlaybackPositionCommand) {
		self.command = command
	}

	var isEnabled: Bool {
		get { command.isEnabled }
		set { command.isEnabled = newValue }
	}

	func addHandler(_ handler: @escaping (TimeInterval) -> Bool) {
		command.addTarget { event in
			guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
			return handler(event.positionTime) ? .success : .commandFailed
		}
	}

	func removeAllHandlers() {
		command.removeTarget(nil)
	}
}

private final class SystemChangePlaybackRateRemoteCommand: ChangePlaybackRateRemoteCommandProtocol {
	private let command: MPChangePlaybackRateCommand

	init(command: MPChangePlaybackRateCommand) {
		self.command = command
	}

	var isEnabled: Bool {
		get { command.isEnabled }
		set { command.isEnabled = newValue }
	}

	func addHandler(_ handler: @escaping (Float) -> Bool) {
		command.addTarget { event in
			guard let event = event as? MPChangePlaybackRateCommandEvent else { return .commandFailed }
			return handler(event.playbackRate) ? .success : .commandFailed
		}
	}

	func removeAllHandlers() {
		command.removeTarget(nil)
	}
}

enum PlaybackRatePolicy {
	static let supportedRates: [Float] = [1.0, 1.25, 1.5, 1.75, 2.0, 2.2, 2.5, 2.8, 3.0]

	private static let formatter: NumberFormatter = {
		let formatter = NumberFormatter()
		formatter.numberStyle = .decimal
		formatter.minimumFractionDigits = 0
		formatter.maximumFractionDigits = 2
		return formatter
	}()

	static func formattedRate(_ rate: Float) -> String {
		formatter.string(from: NSNumber(value: rate)) ?? "\(rate)"
	}

	private static func nearestIndex(to rate: Float) -> Int {
		var bestIndex = 0
		var bestDistance = Float.greatestFiniteMagnitude
		for (index, candidate) in supportedRates.enumerated() {
			let distance = abs(candidate - rate)
			if distance < bestDistance {
				bestDistance = distance
				bestIndex = index
			}
		}
		return bestIndex
	}

	static func normalized(_ rate: Float) -> Float {
		guard rate.isFinite, rate > 0 else { return 1.0 }
		return supportedRates[nearestIndex(to: rate)]
	}

	static func next(after rate: Float) -> Float {
		guard !supportedRates.isEmpty else { return rate }
		let currentIndex = nearestIndex(to: rate)
		let nextIndex = supportedRates.index(after: currentIndex)
		return nextIndex < supportedRates.endIndex ? supportedRates[nextIndex] : supportedRates[0]
	}

	static func previous(before rate: Float) -> Float {
		guard !supportedRates.isEmpty else { return rate }
		let currentIndex = nearestIndex(to: rate)
		let previousIndex = currentIndex - 1
		guard previousIndex >= supportedRates.startIndex else {
			return supportedRates[supportedRates.index(before: supportedRates.endIndex)]
		}
		return supportedRates[previousIndex]
	}
}

struct ResumePositionStore {
	private let userDefaults: UserDefaults
	private let now: () -> Date
	private let throttleInterval: TimeInterval
	private var lastSave: Date

	init(
		userDefaults: UserDefaults,
		now: @escaping () -> Date = { Date() },
		throttleInterval: TimeInterval = 5,
		lastSave: Date = .distantPast
	) {
		self.userDefaults = userDefaults
		self.now = now
		self.throttleInterval = throttleInterval
		self.lastSave = lastSave
	}

	static func makeKey(for url: URL) -> String {
		"resume.\(url.absoluteString)"
	}

	func load(forKey key: String?) -> Double? {
		guard let key else { return nil }
		guard let saved = userDefaults.object(forKey: key) as? Double else { return nil }
		guard saved > 1 else { return nil }
		return saved
	}

	mutating func maybeSave(_ seconds: Double, forKey key: String?) {
		guard let key else { return }
		guard seconds.isFinite else { return }

		let currentTime = now()
		guard currentTime.timeIntervalSince(lastSave) >= throttleInterval else { return }
		lastSave = currentTime

		userDefaults.set(seconds, forKey: key)
	}

	func save(_ seconds: Double, forKey key: String?) {
		guard let key else { return }
		guard seconds.isFinite else { return }
		userDefaults.set(seconds, forKey: key)
	}

	func clear(forKey key: String?) {
		guard let key else { return }
		userDefaults.removeObject(forKey: key)
	}
}

struct PlaybackRateStore {
	private let userDefaults: UserDefaults
	private let globalKey: String

	init(
		userDefaults: UserDefaults,
		globalKey: String = "playbackRate.global"
	) {
		self.userDefaults = userDefaults
		self.globalKey = globalKey
	}

	static func makeKey(for url: URL) -> String {
		"playbackRate.\(url.absoluteString)"
	}

	func loadGlobal() -> Float? {
		let saved = userDefaults.double(forKey: globalKey)
		guard saved.isFinite, saved > 0 else { return nil }
		return PlaybackRatePolicy.normalized(Float(saved))
	}

	func saveGlobal(_ rate: Float) {
		let normalized = PlaybackRatePolicy.normalized(rate)
		userDefaults.set(Double(normalized), forKey: globalKey)
	}

	func load(forKey key: String?) -> Float? {
		guard let key else { return nil }
		let saved = userDefaults.double(forKey: key)
		guard saved.isFinite, saved > 0 else { return nil }
		return PlaybackRatePolicy.normalized(Float(saved))
	}

	func save(_ rate: Float, forKey key: String?) {
		guard let key else { return }
		let normalized = PlaybackRatePolicy.normalized(rate)
		userDefaults.set(Double(normalized), forKey: key)
	}
}

enum SeekPolicy {
	static func clampedTime(_ seconds: Double) -> Double? {
		guard seconds.isFinite else { return nil }
		return max(0, seconds)
	}

	static func targetTime(elapsed: Double, delta: Double) -> Double? {
		guard elapsed.isFinite, delta.isFinite else { return nil }
		return max(0, elapsed + delta)
	}
}

@MainActor
final class AudioPlayer: ObservableObject {
	@Published private(set) var isPlaying = false
	@Published private(set) var currentURL: URL?
	@Published private(set) var currentTitle: String?
	@Published private(set) var currentSubtitle: String?
	@Published private(set) var isLiveStream = false
	@Published private(set) var playbackRate: Float = 1.0
	@Published private(set) var elapsedTime: TimeInterval = 0
	@Published private(set) var duration: TimeInterval?

	private let player: AVPlayer
	private var resumeStore: ResumePositionStore
	private let playbackRateStore: PlaybackRateStore
	private let playbackRateModeProvider: () -> PlaybackRateRememberMode
	private var timeControlStatusObserver: NSKeyValueObservation?
	private var periodicTimeObserver: Any?
	private var endObserver: NSObjectProtocol?
	private var interruptionObserver: NSObjectProtocol?
	private var currentItemStatusObserver: NSKeyValueObservation?

	private var resumeKey: String?
	private var playbackRateKey: String?

	init(
		player: AVPlayer = AVPlayer(),
		userDefaults: UserDefaults = .standard,
		playbackRateModeProvider: @escaping () -> PlaybackRateRememberMode = { .global }
	) {
		self.player = player
		resumeStore = ResumePositionStore(userDefaults: userDefaults)
		playbackRateStore = PlaybackRateStore(userDefaults: userDefaults)
		self.playbackRateModeProvider = playbackRateModeProvider
		player.automaticallyWaitsToMinimizeStalling = true

		timeControlStatusObserver = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
			guard let self else { return }
			Task { @MainActor in
				self.isPlaying = player.timeControlStatus == .playing
				self.updateNowPlayingPlaybackInfo()
			}
		}

		setupRemoteCommands()
		setupNotifications()
		setupPeriodicTimeObserver()
	}

	deinit {
		if let periodicTimeObserver {
			player.removeTimeObserver(periodicTimeObserver)
		}

		if let endObserver {
			NotificationCenter.default.removeObserver(endObserver)
		}

		if let interruptionObserver {
			NotificationCenter.default.removeObserver(interruptionObserver)
		}

		tearDownRemoteCommands()
		timeControlStatusObserver = nil
		currentItemStatusObserver = nil
	}

	func play(
		url: URL,
		title: String? = nil,
		subtitle: String? = nil,
		isLiveStream: Bool = false,
		seekTo seconds: Double? = nil
	) {
		configureAudioSessionForPlayback()

		if currentURL != url {
			persistCurrentPositionIfNeeded()

			currentURL = url
			currentTitle = title
			currentSubtitle = subtitle
			self.isLiveStream = isLiveStream
			resumeKey = isLiveStream ? nil : ResumePositionStore.makeKey(for: url)
			playbackRateKey = isLiveStream ? nil : PlaybackRateStore.makeKey(for: url)

			if !isLiveStream {
				let preferredRate: Float
				switch playbackRateModeProvider() {
				case .global:
					preferredRate = playbackRateStore.loadGlobal() ?? 1.0
				case .perEpisode:
					preferredRate = playbackRateStore.load(forKey: playbackRateKey) ?? 1.0
				}
				playbackRate = preferredRate
			}

			player.replaceCurrentItem(with: AVPlayerItem(url: url))
			if let seconds, !isLiveStream, seconds.isFinite {
				scheduleSeekWhenReady(seconds)
			} else {
				restoreResumePositionIfNeeded()
			}

			updateRemoteCommandAvailability()
			updateNowPlayingMetadata()
		} else if let seconds, !isLiveStream, seconds.isFinite {
			seek(to: seconds)
		}

		if isLiveStream {
			player.play()
		} else {
			player.playImmediately(atRate: playbackRate)
		}
	}

	func pause() {
		player.pause()
		persistCurrentPositionIfNeeded()
		updateNowPlayingPlaybackInfo()
	}

	func resume() {
		guard currentURL != nil else { return }
		configureAudioSessionForPlayback()
		if isLiveStream {
			player.play()
		} else {
			player.playImmediately(atRate: playbackRate)
		}
		updateNowPlayingPlaybackInfo()
	}

	func stop() {
		persistCurrentPositionIfNeeded()
		player.pause()
		player.replaceCurrentItem(with: nil)
		currentURL = nil
		currentTitle = nil
		currentSubtitle = nil
		isLiveStream = false
		elapsedTime = 0
		duration = nil
		resumeKey = nil
		playbackRateKey = nil

		MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
		MPNowPlayingInfoCenter.default().playbackState = .stopped
		updateRemoteCommandAvailability()
	}

	func togglePlayPause(url: URL, title: String? = nil, subtitle: String? = nil, isLiveStream: Bool = false) {
		if currentURL != url {
			play(url: url, title: title, subtitle: subtitle, isLiveStream: isLiveStream)
			return
		}

		if isPlaying {
			pause()
		} else {
			resume()
		}
	}

	@discardableResult
	func toggleCurrentPlayback() -> Bool {
		guard currentURL != nil else { return false }
		if isPlaying {
			pause()
		} else {
			resume()
		}
		return true
	}

	func skipForward(seconds: Double = 30) {
		seek(by: seconds)
	}

	func skipBackward(seconds: Double = 30) {
		seek(by: -seconds)
	}

	func seek(to seconds: Double) {
		guard !isLiveStream else { return }
		guard let clamped = SeekPolicy.clampedTime(seconds) else { return }
		player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600))
		updateNowPlayingPlaybackInfo()
	}

	func cyclePlaybackRate() {
		guard !isLiveStream else { return }
		setPlaybackRate(PlaybackRatePolicy.next(after: playbackRate))
	}

	func setPlaybackRate(_ rate: Float) {
		guard !isLiveStream else { return }
		let normalized = PlaybackRatePolicy.normalized(rate)
		playbackRate = normalized
		persistPlaybackRateIfNeeded(normalized)
		if isPlaying {
			player.rate = normalized
		}
		updateNowPlayingPlaybackInfo()
	}

	func applyPlaybackRateRememberModeChange() {
		guard currentURL != nil else { return }
		guard !isLiveStream else { return }

		let preferredRate: Float
		switch playbackRateModeProvider() {
		case .global:
			preferredRate = playbackRateStore.loadGlobal() ?? 1.0
		case .perEpisode:
			preferredRate = playbackRateStore.load(forKey: playbackRateKey) ?? 1.0
		}

		playbackRate = preferredRate
		if isPlaying {
			player.rate = preferredRate
		}
		updateNowPlayingPlaybackInfo()
	}

	private func persistPlaybackRateIfNeeded(_ rate: Float) {
		switch playbackRateModeProvider() {
		case .global:
			playbackRateStore.saveGlobal(rate)
		case .perEpisode:
			playbackRateStore.save(rate, forKey: playbackRateKey)
		}
	}

	private func configureAudioSessionForPlayback() {
		let session = AVAudioSession.sharedInstance()
		do {
			try session.setCategory(.playback, mode: .default)
			try session.setActive(true)
		} catch {
			// No-op: audio may still play, but without preferred session behavior.
		}
	}

	private func seek(by deltaSeconds: Double) {
		guard !isLiveStream else { return }
		guard let currentItem = player.currentItem else { return }
		guard currentItem.status == .readyToPlay else { return }

		guard let target = SeekPolicy.targetTime(elapsed: elapsedTime, delta: deltaSeconds) else { return }
		seek(to: target)
	}

	private func setupPeriodicTimeObserver() {
		let interval = CMTime(seconds: 1, preferredTimescale: 2)
		periodicTimeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
			guard let self else { return }
			let seconds = time.seconds
			if seconds.isFinite {
				self.elapsedTime = seconds
			}

			let durationSeconds = self.player.currentItem?.duration.seconds
			if let durationSeconds, durationSeconds.isFinite, durationSeconds > 0 {
				self.duration = durationSeconds
			} else {
				self.duration = nil
			}

			self.maybePersistResumeTime(seconds)
			self.updateNowPlayingPlaybackInfo()
		}
	}

	private func setupNotifications() {
		interruptionObserver = NotificationCenter.default.addObserver(
			forName: AVAudioSession.interruptionNotification,
			object: AVAudioSession.sharedInstance(),
			queue: .main
		) { [weak self] notification in
			guard let self else { return }
			guard let userInfo = notification.userInfo,
			      let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
			      let type = AVAudioSession.InterruptionType(rawValue: typeValue)
			else {
				return
			}

			switch type {
			case .began:
				self.pause()
			case .ended:
				let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt
				let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue ?? 0)
				if options.contains(.shouldResume), self.currentURL != nil {
					if self.isLiveStream {
						self.player.play()
					} else {
						self.player.playImmediately(atRate: self.playbackRate)
					}
				}
			@unknown default:
				break
			}
		}

		endObserver = NotificationCenter.default.addObserver(
			forName: .AVPlayerItemDidPlayToEndTime,
			object: nil,
			queue: .main
		) { [weak self] notification in
			guard let self else { return }
			guard let item = notification.object as? AVPlayerItem else { return }
			guard item === self.player.currentItem else { return }

			self.isPlaying = false
			if let resumeKey = self.resumeKey {
				self.resumeStore.clear(forKey: resumeKey)
			}
			self.updateNowPlayingPlaybackInfo()
		}
	}

	private func setupRemoteCommands() {
		let center = SystemRemoteCommandCenter()

		RemoteCommandWiring.install(
			center: center,
			play: { [weak self] in
				guard let self else { return false }
				Task { @MainActor in
					guard self.currentURL != nil else { return }
					self.configureAudioSessionForPlayback()
					if self.isLiveStream {
						self.player.play()
					} else {
						self.player.playImmediately(atRate: self.playbackRate)
					}
					self.updateNowPlayingPlaybackInfo()
				}
				return true
			},
			pause: { [weak self] in
				guard let self else { return false }
				Task { @MainActor in
					self.pause()
				}
				return true
			},
			togglePlayPause: { [weak self] in
				guard let self else { return false }
				Task { @MainActor in
					guard self.currentURL != nil else { return }
					if self.isPlaying {
						self.pause()
					} else {
						self.resume()
					}
				}
				return true
			},
			skipForward: { [weak self] interval in
				guard let self else { return false }
				Task { @MainActor in
					self.skipForward(seconds: interval)
				}
				return true
			},
			skipBackward: { [weak self] interval in
				guard let self else { return false }
				Task { @MainActor in
					self.skipBackward(seconds: interval)
				}
				return true
			},
			changePlaybackPosition: { [weak self] position in
				guard let self else { return false }
				Task { @MainActor in
					self.seek(to: position)
				}
				return true
			},
			changePlaybackRate: { [weak self] rate in
				guard let self else { return false }
				Task { @MainActor in
					self.setPlaybackRate(rate)
				}
				return true
			}
		)

		updateRemoteCommandAvailability()
	}

	private nonisolated func tearDownRemoteCommands() {
		let commandCenter = MPRemoteCommandCenter.shared()
		commandCenter.playCommand.removeTarget(nil)
		commandCenter.pauseCommand.removeTarget(nil)
		commandCenter.togglePlayPauseCommand.removeTarget(nil)
		commandCenter.skipForwardCommand.removeTarget(nil)
		commandCenter.skipBackwardCommand.removeTarget(nil)
		commandCenter.changePlaybackPositionCommand.removeTarget(nil)
		commandCenter.changePlaybackRateCommand.removeTarget(nil)
	}

	private func updateRemoteCommandAvailability() {
		let commandCenter = MPRemoteCommandCenter.shared()

		let hasItem = currentURL != nil
		commandCenter.playCommand.isEnabled = hasItem
		commandCenter.pauseCommand.isEnabled = hasItem
		commandCenter.togglePlayPauseCommand.isEnabled = hasItem

		let seekable = hasItem && !isLiveStream
		commandCenter.skipForwardCommand.isEnabled = seekable
		commandCenter.skipBackwardCommand.isEnabled = seekable
		commandCenter.changePlaybackPositionCommand.isEnabled = seekable
		commandCenter.changePlaybackRateCommand.isEnabled = seekable
	}

	private func updateNowPlayingMetadata() {
		var info: [String: Any] = [:]

		if let currentTitle, !currentTitle.isEmpty {
			info[MPMediaItemPropertyTitle] = currentTitle
		}

		if let currentSubtitle, !currentSubtitle.isEmpty {
			info[MPMediaItemPropertyArtist] = currentSubtitle
		}

		info[MPNowPlayingInfoPropertyIsLiveStream] = isLiveStream

		MPNowPlayingInfoCenter.default().nowPlayingInfo = info
		updateNowPlayingPlaybackInfo()
	}

	private func updateNowPlayingPlaybackInfo() {
		guard currentURL != nil else { return }

		var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]

		if !isLiveStream {
			info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsedTime
			if let duration {
				info[MPMediaItemPropertyPlaybackDuration] = duration
			}
			info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackRate : 0.0
		} else {
			info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
		}

		MPNowPlayingInfoCenter.default().nowPlayingInfo = info
		MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
	}

	private func restoreResumePositionIfNeeded() {
		guard let saved = resumeStore.load(forKey: resumeKey) else { return }

		scheduleSeekWhenReady(saved)
	}

	private func scheduleSeekWhenReady(_ seconds: Double) {
		currentItemStatusObserver = player.currentItem?.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
			guard let self else { return }
			guard item.status == .readyToPlay else { return }

			Task { @MainActor in
				self.seek(to: seconds)
				self.currentItemStatusObserver = nil
			}
		}
	}

	private func maybePersistResumeTime(_ seconds: Double) {
		guard !isLiveStream else { return }
		resumeStore.maybeSave(seconds, forKey: resumeKey)
	}

	private func persistCurrentPositionIfNeeded() {
		guard !isLiveStream else { return }
		resumeStore.save(elapsedTime, forKey: resumeKey)
	}
}
