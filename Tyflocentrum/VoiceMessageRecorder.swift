//
//  VoiceMessageRecorder.swift
//  Tyflocentrum
//
//  Created by Codex on 27/01/2026.
//

import AVFoundation
import Foundation

protocol AudioSessionProtocol: AnyObject {
	var category: AVAudioSession.Category { get }
	var mode: AVAudioSession.Mode { get }

	func setCategory(_ category: AVAudioSession.Category, mode: AVAudioSession.Mode, options: AVAudioSession.CategoryOptions) throws
	func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws
	func overrideOutputAudioPort(_ portOverride: AVAudioSession.PortOverride) throws
	func requestRecordPermission(_ response: @escaping (Bool) -> Void)

	@available(iOS 13.0, *)
	func setAllowHapticsAndSystemSoundsDuringRecording(_ inValue: Bool) throws
}

extension AVAudioSession: AudioSessionProtocol {}

@MainActor
final class VoiceMessageRecorder: NSObject, ObservableObject {
	enum State: Equatable {
		case idle
		case recording
		case recorded
		case playingPreview
	}

	@Published private(set) var state: State = .idle
	@Published private(set) var isProcessing: Bool = false
	@Published private(set) var elapsedTime: TimeInterval = 0
	@Published private(set) var recordedDurationMs: Int = 0
	@Published var shouldShowError = false
	@Published var errorMessage = ""

	private var recorder: AVAudioRecorder?
	private var previewPlayer: AVAudioPlayer?
	private var timer: Timer?
	private(set) var recordedFileURL: URL?
	private var activeRecordingFileURL: URL?
	private var appendBaseFileURL: URL?
	private var recordingElapsedTimeOffset: TimeInterval = 0
	private var activeExportSession: AVAssetExportSession?
	private var recordingTotalMaxDurationSeconds: TimeInterval = 20 * 60
	private let audioSession: AudioSessionProtocol

	var canSend: Bool {
		guard !isProcessing else { return false }
		guard state == .recorded || state == .playingPreview else { return false }
		return recordedFileIsUsable()
	}

	init(audioSession: AudioSessionProtocol = AVAudioSession.sharedInstance()) {
		self.audioSession = audioSession
		super.init()
	}

	static func configureAudioSessionForRecording(_ session: AudioSessionProtocol) throws {
		try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth])
		if #available(iOS 13.0, *) {
			try session.setAllowHapticsAndSystemSoundsDuringRecording(true)
		}
		try session.setActive(true, options: [])
	}

	func startRecording(maxDurationSeconds: TimeInterval = 20 * 60, pausing audioPlayer: AudioPlayer? = nil) async {
		guard state != .recording else { return }
		guard !isProcessing else { return }

		recordingTotalMaxDurationSeconds = maxDurationSeconds
		stopPreviewIfNeeded()

		let hasPermission = await requestMicrophonePermission()
		guard hasPermission else {
			showError("Brak dostępu do mikrofonu. Włącz uprawnienia w Ustawieniach.")
			return
		}

		if audioPlayer?.isPlaying == true {
			audioPlayer?.pause()
		}

		let shouldAppend = (state == .recorded || state == .playingPreview) && recordedFileIsUsable()
		let baseDurationSeconds = shouldAppend ? TimeInterval(recordedDurationMs) / 1000.0 : 0
		let remainingSeconds = maxDurationSeconds - baseDurationSeconds
		guard remainingSeconds > 0.1 else {
			showError("Osiągnięto limit długości nagrania.")
			return
		}

		do {
			try Self.configureAudioSessionForRecording(audioSession)

			if !shouldAppend {
				stopRecording()
				cleanupRecordingFile()
				recordedDurationMs = 0
			}

			let fileURL = FileManager.default.temporaryDirectory
				.appendingPathComponent("voice-seg-\(UUID().uuidString)")
				.appendingPathExtension("m4a")

			let settings: [String: Any] = [
				AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
				AVSampleRateKey: 44100,
				AVNumberOfChannelsKey: 1,
				AVEncoderBitRateKey: 160_000,
				AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
			]

			let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
			recorder.delegate = self
			recorder.isMeteringEnabled = true
			recorder.prepareToRecord()

			self.recorder = recorder
			activeRecordingFileURL = fileURL
			appendBaseFileURL = shouldAppend ? recordedFileURL : nil
			recordingElapsedTimeOffset = baseDurationSeconds
			elapsedTime = baseDurationSeconds
			state = .recording

			recorder.record(forDuration: remainingSeconds)
			startTimer { [weak self] in
				guard let self else { return }
				guard let recorder = self.recorder else { return }
				self.elapsedTime = self.recordingElapsedTimeOffset + recorder.currentTime
			}
		} catch {
			cleanupActiveRecordingFile()
			showError("Nie udało się rozpocząć nagrywania.")
		}
	}

	func stopRecording() {
		guard state == .recording else { return }
		let elapsedTimeSnapshot = elapsedTime
		timer?.invalidate()
		timer = nil

		let baseFileURL = appendBaseFileURL
		let baseDurationSeconds = recordingElapsedTimeOffset
		let maxDurationSeconds = recordingTotalMaxDurationSeconds
		appendBaseFileURL = nil
		recordingElapsedTimeOffset = 0

		defer {
			deactivateAudioSession()
		}

		guard let recorder else {
			cleanupActiveRecordingFile()
			state = baseFileURL != nil ? .recorded : .idle
			elapsedTime = baseDurationSeconds
			return
		}

		let durationSecondsSnapshot = recorder.currentTime
		recorder.stop()
		self.recorder = nil

		guard let segmentURL = activeRecordingFileURL else {
			state = baseFileURL != nil ? .recorded : .idle
			elapsedTime = baseDurationSeconds
			return
		}
		activeRecordingFileURL = nil

		let segmentElapsedTime = max(0, elapsedTimeSnapshot - baseDurationSeconds)
		var segmentDurationSeconds = max(durationSecondsSnapshot, segmentElapsedTime)
		if segmentDurationSeconds <= 0 {
			let asset = AVURLAsset(url: segmentURL)
			let assetSeconds = asset.duration.seconds
			if assetSeconds.isFinite, assetSeconds > 0 {
				segmentDurationSeconds = assetSeconds
			}
		}

		let segmentFileSize = (try? segmentURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
		guard segmentFileSize > 0, segmentDurationSeconds > 0 else {
			try? FileManager.default.removeItem(at: segmentURL)
			elapsedTime = baseDurationSeconds
			state = baseFileURL != nil ? .recorded : .idle
			return
		}

		if let baseFileURL {
			beginMerging(baseURL: baseFileURL, segmentURL: segmentURL, totalMaxDurationSeconds: maxDurationSeconds)
			return
		}

		recordedFileURL = segmentURL
		let totalSeconds = segmentDurationSeconds
		let durationMs = Int((totalSeconds * 1000.0).rounded())
		recordedDurationMs = max(0, durationMs)
		elapsedTime = totalSeconds
		state = recordedFileIsUsable() ? .recorded : .idle
		if state == .idle {
			cleanupRecordingFile()
		}
	}

	private func beginMerging(baseURL: URL, segmentURL: URL, totalMaxDurationSeconds: TimeInterval) {
		guard !isProcessing else { return }
		isProcessing = true
		state = .recorded
		activeExportSession?.cancelExport()
		activeExportSession = nil

		Task.detached(priority: .userInitiated) { [weak self] in
			guard let self else { return }
			do {
				let mergedURL = try await Self.mergeAudio(
					baseURL: baseURL,
					appendedURL: segmentURL,
					exportSessionSetter: { exportSession in
						Task { @MainActor in
							self.activeExportSession = exportSession
						}
					}
				)

				let mergedSeconds = AVURLAsset(url: mergedURL).duration.seconds
				let durationMs = Int((max(0, mergedSeconds) * 1000.0).rounded())

				await MainActor.run {
					self.activeExportSession = nil
					self.isProcessing = false
					if mergedSeconds > totalMaxDurationSeconds + 0.5 {
						self.showError("Nagranie przekroczyło limit długości.")
					}
					self.recordedFileURL = mergedURL
					self.recordedDurationMs = max(0, durationMs)
					self.elapsedTime = TimeInterval(self.recordedDurationMs) / 1000.0
					self.state = self.recordedFileIsUsable() ? .recorded : .idle
				}

				try? FileManager.default.removeItem(at: baseURL)
				try? FileManager.default.removeItem(at: segmentURL)
			} catch {
				try? FileManager.default.removeItem(at: segmentURL)
				await MainActor.run {
					self.activeExportSession = nil
					self.isProcessing = false
					self.elapsedTime = TimeInterval(self.recordedDurationMs) / 1000.0
					self.state = self.recordedFileIsUsable() ? .recorded : .idle
					if !(error is CancellationError) {
						self.showError("Nie udało się dograć nagrania.")
					}
				}
			}
		}
	}

	private enum MergeError: Error {
		case missingAudioTrack
		case exportFailed
	}

	private static func mergeAudio(
		baseURL: URL,
		appendedURL: URL,
		exportSessionSetter: (AVAssetExportSession) -> Void
	) async throws -> URL {
		let baseAsset = AVURLAsset(url: baseURL)
		let appendedAsset = AVURLAsset(url: appendedURL)

		let composition = AVMutableComposition()
		guard let compositionTrack = composition.addMutableTrack(
			withMediaType: .audio,
			preferredTrackID: kCMPersistentTrackID_Invalid
		) else {
			throw MergeError.missingAudioTrack
		}

		var cursor = CMTime.zero
		for asset in [baseAsset, appendedAsset] {
			guard let track = asset.tracks(withMediaType: .audio).first else {
				throw MergeError.missingAudioTrack
			}
			let timeRange = CMTimeRange(start: .zero, duration: asset.duration)
			try compositionTrack.insertTimeRange(timeRange, of: track, at: cursor)
			cursor = cursor + asset.duration
		}

		let outputURL = FileManager.default.temporaryDirectory
			.appendingPathComponent("voice-merged-\(UUID().uuidString)")
			.appendingPathExtension("m4a")
		if FileManager.default.fileExists(atPath: outputURL.path) {
			try? FileManager.default.removeItem(at: outputURL)
		}

		guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
			throw MergeError.exportFailed
		}
		export.outputURL = outputURL
		export.outputFileType = .m4a
		export.shouldOptimizeForNetworkUse = true
		exportSessionSetter(export)

		try await withCheckedThrowingContinuation { continuation in
			export.exportAsynchronously {
				switch export.status {
				case .completed:
					continuation.resume(returning: ())
				case .cancelled:
					continuation.resume(throwing: CancellationError())
				default:
					continuation.resume(throwing: export.error ?? MergeError.exportFailed)
				}
			}
		}

		return outputURL
	}

	private func recordedFileIsUsable() -> Bool {
		guard let url = recordedFileURL else { return false }
		let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
		return fileSize > 0
	}

	func togglePreview() {
		guard !isProcessing else { return }
		switch state {
		case .playingPreview:
			stopPreviewIfNeeded()
			state = recordedFileIsUsable() ? .recorded : .idle
		case .recorded:
			startPreview()
		default:
			break
		}
	}

	func reset() {
		activeExportSession?.cancelExport()
		activeExportSession = nil
		isProcessing = false

		stopPreviewIfNeeded()
		timer?.invalidate()
		timer = nil

		recorder?.stop()
		recorder = nil
		appendBaseFileURL = nil
		recordingElapsedTimeOffset = 0
		cleanupActiveRecordingFile()
		cleanupRecordingFile()
		recordedDurationMs = 0
		elapsedTime = 0
		state = .idle
		deactivateAudioSession()
	}

	#if DEBUG
		func seedRecordedForUITesting(durationMs: Int = 5000) {
			guard ProcessInfo.processInfo.arguments.contains("UI_TESTING") else { return }

			stopPreviewIfNeeded()
			timer?.invalidate()
			timer = nil

			recorder?.stop()
			recorder = nil

			cleanupRecordingFile()

			let durationSeconds = max(0.05, TimeInterval(durationMs) / 1000.0)
			let sampleRate = 44100
			let fileURL = FileManager.default.temporaryDirectory
				.appendingPathComponent("ui-test-voice-\(UUID().uuidString)")
				.appendingPathExtension("wav")
			let wavData = Self.makeSilentWAVData(sampleRate: sampleRate, durationSeconds: durationSeconds)
			try? wavData.write(to: fileURL, options: .atomic)

			recordedFileURL = fileURL
			recordedDurationMs = max(1, durationMs)
			elapsedTime = TimeInterval(recordedDurationMs) / 1000.0
			state = .recorded
		}

		private static func makeSilentWAVData(sampleRate: Int, durationSeconds: TimeInterval) -> Data {
			let channels: UInt16 = 1
			let bitsPerSample: UInt16 = 16
			let blockAlign = channels * (bitsPerSample / 8)
			let byteRate = UInt32(sampleRate) * UInt32(blockAlign)
			let sampleCount = max(1, Int((Double(sampleRate) * durationSeconds).rounded(.up)))
			let dataSize = UInt32(sampleCount) * UInt32(blockAlign)
			let riffSize = 36 + dataSize

			var data = Data()
			data.reserveCapacity(44 + Int(dataSize))

			data.appendASCII("RIFF")
			data.appendUInt32LE(riffSize)
			data.appendASCII("WAVE")

			data.appendASCII("fmt ")
			data.appendUInt32LE(16) // PCM header size
			data.appendUInt16LE(1) // PCM
			data.appendUInt16LE(channels)
			data.appendUInt32LE(UInt32(sampleRate))
			data.appendUInt32LE(byteRate)
			data.appendUInt16LE(blockAlign)
			data.appendUInt16LE(bitsPerSample)

			data.appendASCII("data")
			data.appendUInt32LE(dataSize)

			data.append(contentsOf: repeatElement(0, count: Int(dataSize)))
			return data
		}
	#endif

	private func startPreview() {
		guard let url = recordedFileURL else { return }
		DispatchQueue.global(qos: .userInitiated).async { [weak self] in
			do {
				let player = try AVAudioPlayer(contentsOf: url)
				player.prepareToPlay()

				DispatchQueue.main.async { [weak self] in
					guard let self else { return }
					guard self.recordedFileURL == url else { return }
					guard self.state == .recorded else { return }
					do {
						if self.audioSession.category != .playback || self.audioSession.mode != .default {
							try self.audioSession.setCategory(.playback, mode: .default, options: [])
						}
						try self.audioSession.setActive(true, options: [])
					} catch {
						self.showError("Nie udało się przygotować odsłuchu nagrania.")
						return
					}

					player.delegate = self
					let didStart = player.play()
					guard didStart else {
						self.showError("Nie udało się rozpocząć odsłuchu nagrania.")
						return
					}

					self.previewPlayer = player
					self.state = .playingPreview
				}
			} catch {
				DispatchQueue.main.async { [weak self] in
					self?.showError("Nie udało się odtworzyć nagrania.")
				}
			}
		}
	}

	private func stopPreviewIfNeeded() {
		timer?.invalidate()
		timer = nil

		previewPlayer?.stop()
		previewPlayer = nil
		deactivateAudioSession()
	}

	private func startTimer(tick: @escaping () -> Void) {
		timer?.invalidate()
		timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
			tick()
		}
	}

	private func cleanupRecordingFile() {
		if let url = recordedFileURL {
			try? FileManager.default.removeItem(at: url)
		}
		recordedFileURL = nil
	}

	private func cleanupActiveRecordingFile() {
		if let url = activeRecordingFileURL {
			try? FileManager.default.removeItem(at: url)
		}
		activeRecordingFileURL = nil
	}

	private func deactivateAudioSession() {
		try? audioSession.overrideOutputAudioPort(.none)
		try? audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
	}

	private func requestMicrophonePermission() async -> Bool {
		return await withCheckedContinuation { continuation in
			audioSession.requestRecordPermission { granted in
				continuation.resume(returning: granted)
			}
		}
	}

	private func showError(_ message: String) {
		errorMessage = message
		shouldShowError = true
	}
}

#if DEBUG
	private extension Data {
		mutating func appendASCII(_ string: String) {
			if let data = string.data(using: .ascii) {
				append(data)
			}
		}

		mutating func appendUInt16LE(_ value: UInt16) {
			var v = value.littleEndian
			Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
		}

		mutating func appendUInt32LE(_ value: UInt32) {
			var v = value.littleEndian
			Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
		}
	}
#endif

extension VoiceMessageRecorder: AVAudioRecorderDelegate {
	nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
		Task { @MainActor in
			guard self.recorder === recorder else { return }
			if flag {
				self.stopRecording()
				return
			}

			let segmentURL = self.activeRecordingFileURL
			let segmentFileSize = (try? segmentURL?.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
			if segmentFileSize > 0 {
				self.stopRecording()
				return
			}

			self.cleanupActiveRecordingFile()
			self.appendBaseFileURL = nil
			self.recordingElapsedTimeOffset = 0
			self.timer?.invalidate()
			self.timer = nil
			self.recorder = nil

			self.elapsedTime = TimeInterval(self.recordedDurationMs) / 1000.0
			self.state = self.recordedFileIsUsable() ? .recorded : .idle
			self.showError("Nagrywanie nie powiodło się.")
		}
	}
}

extension VoiceMessageRecorder: AVAudioPlayerDelegate {
	nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
		Task { @MainActor in
			guard self.previewPlayer === player else { return }
			self.timer?.invalidate()
			self.timer = nil
			self.previewPlayer = nil
			self.elapsedTime = TimeInterval(self.recordedDurationMs) / 1000.0
			self.state = self.recordedFileIsUsable() ? .recorded : .idle
			self.deactivateAudioSession()
			if !flag {
				self.showError("Nie udało się odtworzyć nagrania.")
			}
		}
	}

	nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
		Task { @MainActor in
			guard self.previewPlayer === player else { return }
			self.stopPreviewIfNeeded()
			self.elapsedTime = TimeInterval(self.recordedDurationMs) / 1000.0
			self.state = self.recordedFileIsUsable() ? .recorded : .idle
			self.showError(error?.localizedDescription ?? "Nie udało się odtworzyć nagrania.")
		}
	}
}
