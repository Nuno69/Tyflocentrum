//
//  ContactVoiceMessageView.swift
//  Tyflocentrum
//

import AVFoundation
import SwiftUI
import UIKit

struct ContactVoiceMessageView: View {
	@EnvironmentObject var api: TyfloAPI
	@EnvironmentObject var audioPlayer: AudioPlayer
	@EnvironmentObject var magicTapCoordinator: MagicTapCoordinator
	@Environment(\.dismiss) private var dismiss

	@StateObject private var viewModel = ContactViewModel()
	@StateObject private var voiceRecorder = VoiceMessageRecorder()

	@State private var magicTapToken: UUID?
	@State private var startRecordingTask: Task<Void, Never>?
	@State private var recordingTrigger: RecordingTrigger?
	@State private var isEarModeEnabled = false
	@State private var isHoldingToTalk = false
	@State private var isHoldToTalkLocked = false
	@State private var holdToTalkStartTask: Task<Void, Never>?

	@AccessibilityFocusState private var focusedField: Field?

	private enum Field: Hashable {
		case name
	}

	private enum RecordingTrigger {
		case magicTap
		case holdToTalk
		case proximity
	}

	private var supportsEarMode: Bool {
		DeviceCapabilities.supportsProximityRecording
	}

	var body: some View {
		let hasName = !viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
		let canSendVoice = hasName && voiceRecorder.canSend && !viewModel.isSending
		let isRecording = voiceRecorder.state == .recording
		let isProcessing = voiceRecorder.isProcessing

		Form {
			Section {
				TextField("Imię", text: $viewModel.name)
					.textContentType(.name)
					.accessibilityIdentifier("contact.name")
					.accessibilityHint("Wpisz imię, które będzie widoczne przy wiadomości.")
					.accessibilityFocused($focusedField, equals: .name)
					.disabled(viewModel.isSending || isRecording || isProcessing)
					.accessibilityHidden(viewModel.isSending)
			}

			Section("Nagrywanie") {
				if supportsEarMode {
					Toggle("Nagrywaj po przyłożeniu telefonu do ucha", isOn: $isEarModeEnabled)
						.accessibilityIdentifier("contact.voice.earMode")
						.accessibilityHint(hasName ? "Gdy włączone, przyłożenie telefonu do ucha rozpoczyna nagrywanie, a oderwanie kończy." : "Najpierw uzupełnij imię, aby włączyć ten tryb.")
						.disabled(viewModel.isSending || isRecording || isProcessing || !hasName)
						.accessibilityHidden(viewModel.isSending || !hasName)
				}

				Text("Magic Tap: rozpocznij/zatrzymaj nagrywanie. Możesz dogrywać kolejne fragmenty. Przytrzymaj przycisk i mów, aby nagrywać bez gadania VoiceOvera.")
					.font(.footnote)
					.foregroundColor(.secondary)
					.accessibilityIdentifier("contact.voice.instructions")

				HStack {
					Image(systemName: "mic.fill")
						.accessibilityHidden(true)
					Text(holdToTalkVisualLabel(isRecording: isRecording))
						.fontWeight(.semibold)
				}
				.frame(maxWidth: .infinity, minHeight: 56)
				.contentShape(Rectangle())
				.background(Color.accentColor.opacity(0.12))
				.cornerRadius(12)
				.gesture(makeHoldToTalkGesture(hasName: hasName))
				.accessibilityElement(children: .ignore)
				.accessibilityLabel(holdToTalkAccessibilityLabel(isRecording: isRecording))
				.accessibilityAddTraits(.isButton)
				.accessibilityIdentifier("contact.voice.holdToTalk")
				.accessibilityHint("Przytrzymaj, aby mówić. Puść, aby zakończyć. Przeciągnij w górę, aby zablokować nagrywanie.")
				.disabled(
					viewModel.isSending
						|| !hasName
						|| isProcessing
						|| (voiceRecorder.state == .recording && recordingTrigger != .holdToTalk)
				)
				.accessibilityHidden(
					viewModel.isSending
						|| !hasName
						|| isProcessing
						|| (voiceRecorder.state == .recording && recordingTrigger != .holdToTalk)
				)

				HStack {
					if isRecording || isProcessing {
						ProgressView()
					}
					Text(recordingStatusText(isRecording: isRecording, isProcessing: isProcessing))
				}
				.accessibilityElement(children: .combine)
				.accessibilityIdentifier("contact.voice.recordingStatus")

				if isRecording {
					Button("Zatrzymaj") {
						stopRecording(silent: false)
					}
					.accessibilityIdentifier("contact.voice.stop")
					.accessibilityHint("Zatrzymuje nagrywanie. Możesz też użyć Magic Tap lub oderwać telefon od ucha.")
					.disabled(viewModel.isSending)
					.accessibilityHidden(viewModel.isSending)
				}
			}

			if voiceRecorder.state == .recorded || voiceRecorder.state == .playingPreview {
				Section("Nagranie") {
					Text("Długość: \(formatTime(TimeInterval(voiceRecorder.recordedDurationMs) / 1000.0))")
						.accessibilityIdentifier("contact.voice.duration")

					Button(voiceRecorder.state == .playingPreview ? "Zatrzymaj odsłuch" : "Odsłuchaj") {
						voiceRecorder.togglePreview()
					}
					.accessibilityIdentifier("contact.voice.preview")
					.accessibilityHint("Odtwarza nagraną głosówkę.")
					.disabled(viewModel.isSending || isProcessing)

					Button("Usuń nagranie", role: .destructive) {
						resetRecording()
						UIAccessibility.post(notification: .announcement, argument: "Nagranie usunięte")
					}
					.accessibilityIdentifier("contact.voice.delete")
					.accessibilityHint("Usuwa nagraną głosówkę.")
					.disabled(viewModel.isSending || isProcessing)

					Button {
						Task { @MainActor in
							guard let url = voiceRecorder.recordedFileURL else { return }
							let didSend = await viewModel.sendVoice(using: api, audioFileURL: url, durationMs: voiceRecorder.recordedDurationMs)
							guard didSend else { return }

							resetRecording()
							UIAccessibility.post(notification: .announcement, argument: "Głosówka wysłana pomyślnie")
							dismiss()
						}
					} label: {
						if viewModel.isSending {
							HStack {
								ProgressView()
								Text("Wysyłanie…")
							}
							.accessibilityElement(children: .combine)
						} else {
							Text("Wyślij głosówkę")
						}
					}
					.disabled(!canSendVoice)
					.accessibilityIdentifier("contact.voice.send")
					.accessibilityHint(canSendVoice ? "Wysyła głosówkę do redakcji." : "Wpisz imię i nagraj głosówkę, aby wysłać.")
				}
			}
		}
		.accessibilityIdentifier("contactVoice.form")
		.navigationTitle("Głosówka")
		.navigationBarTitleDisplayMode(.inline)
		.accessibilityAction(.escape) {
			handleEscape()
		}
		.alert("Błąd", isPresented: $viewModel.shouldShowError) {
			Button("OK") {}
		} message: {
			Text(viewModel.errorMessage)
		}
		.alert("Błąd", isPresented: $voiceRecorder.shouldShowError) {
			Button("OK") {}
		} message: {
			Text(voiceRecorder.errorMessage)
		}
		.task {
			if viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
				focusedField = .name
			}
			#if DEBUG
				if ProcessInfo.processInfo.arguments.contains("UI_TESTING_SEED_VOICE_RECORDED") {
					voiceRecorder.seedRecordedForUITesting()
				}
			#endif
		}
		.onAppear {
			if !supportsEarMode, isEarModeEnabled {
				isEarModeEnabled = false
			}
			registerMagicTapOverrideIfNeeded()
		}
		.onDisappear {
			unregisterMagicTapOverride()
			disableProximityMonitoring()
			resetRecording()
		}
		.onChange(of: isEarModeEnabled) { enabled in
			guard supportsEarMode else {
				isEarModeEnabled = false
				return
			}
			if enabled {
				enableProximityMonitoring()
			} else {
				disableProximityMonitoring()
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: UIDevice.proximityStateDidChangeNotification)) { _ in
			guard supportsEarMode, isEarModeEnabled else { return }
			handleProximityChange()
		}
		.onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { notification in
			handleAudioSessionInterruption(notification)
		}
	}

	private func registerMagicTapOverrideIfNeeded() {
		guard magicTapToken == nil else { return }
		magicTapToken = magicTapCoordinator.push {
			handleMagicTap()
		}
	}

	private func unregisterMagicTapOverride() {
		if let magicTapToken {
			magicTapCoordinator.remove(magicTapToken)
			self.magicTapToken = nil
		}
	}

	private func handleMagicTap() -> Bool {
		guard !viewModel.isSending else { return true }

		switch voiceRecorder.state {
		case .recording:
			stopRecording(silent: false)
		case .idle:
			startRecording(trigger: .magicTap, announceBeforeStart: true)
		case .recorded, .playingPreview:
			startRecording(trigger: .magicTap, announceBeforeStart: true)
		}
		return true
	}

	private func startRecording(trigger: RecordingTrigger, announceBeforeStart: Bool) {
		guard voiceRecorder.state != .recording else { return }
		guard !voiceRecorder.isProcessing else { return }
		guard !viewModel.isSending else { return }
		guard !viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
			viewModel.errorMessage = "Uzupełnij imię, aby nagrać głosówkę."
			viewModel.shouldShowError = true
			return
		}

		recordingTrigger = trigger
		startRecordingTask?.cancel()

		if audioPlayer.isPlaying {
			audioPlayer.pause()
		}

		let isAppending = voiceRecorder.state == .recorded || voiceRecorder.state == .playingPreview
		startRecordingTask = Task { @MainActor in
			if trigger == .magicTap {
				let announcement = isAppending ? "Dogrywaj wiadomość po sygnale." : "Nagrywaj wiadomość po sygnale."
				if announceBeforeStart, UIAccessibility.isVoiceOverRunning {
					UIAccessibility.post(notification: .announcement, argument: announcement)
					await waitForVoiceOverAnnouncementToFinish(announcement)
					guard !Task.isCancelled else { return }
					try? await Task.sleep(nanoseconds: 200_000_000)
					guard !Task.isCancelled else { return }
				}

				AudioCuePlayer.shared.playStartCue()
				playHaptic(times: 2, style: .heavy, intensity: 1.0)
				let cueDelay = AudioCuePlayer.shared.startCueDurationSeconds + 0.1
				try? await Task.sleep(nanoseconds: UInt64(cueDelay * 1_000_000_000))
				guard !Task.isCancelled else { return }
			}

			guard !Task.isCancelled else { recordingTrigger = nil; return }
			await voiceRecorder.startRecording(pausing: audioPlayer)
			if Task.isCancelled {
				if voiceRecorder.state == .recording {
					voiceRecorder.stopRecording()
				}
				recordingTrigger = nil
				isHoldToTalkLocked = false
				return
			}

			if voiceRecorder.state == .recording {
				if trigger == .proximity {
					playHaptic(times: 2, style: .heavy, intensity: 1.0)
				}
				if trigger == .holdToTalk {
					playHaptic(times: 2, style: .heavy, intensity: 1.0)
				}
				if trigger == .holdToTalk, !isHoldingToTalk, !isHoldToTalkLocked {
					voiceRecorder.stopRecording()
					recordingTrigger = nil
					return
				}
			} else {
				recordingTrigger = nil
			}
		}
	}

	private func stopRecording(silent: Bool) {
		let trigger = recordingTrigger
		startRecordingTask?.cancel()
		startRecordingTask = nil
		holdToTalkStartTask?.cancel()
		holdToTalkStartTask = nil
		isHoldingToTalk = false

		if voiceRecorder.state == .recording {
			voiceRecorder.stopRecording()
		}
		recordingTrigger = nil
		isHoldToTalkLocked = false
		if !silent {
			playHaptic(times: 1, style: .heavy, intensity: 1.0)
			if trigger == .magicTap {
				AudioCuePlayer.shared.playStopCue()
			}
		}
	}

	private func resetRecording() {
		startRecordingTask?.cancel()
		startRecordingTask = nil
		holdToTalkStartTask?.cancel()
		holdToTalkStartTask = nil
		recordingTrigger = nil
		isHoldToTalkLocked = false
		isHoldingToTalk = false
		voiceRecorder.reset()
	}

	private func enableProximityMonitoring() {
		guard supportsEarMode else { return }
		UIDevice.current.isProximityMonitoringEnabled = true
		handleProximityChange()
	}

	private func disableProximityMonitoring() {
		guard supportsEarMode else { return }
		UIDevice.current.isProximityMonitoringEnabled = false
	}

	private func handleProximityChange() {
		guard supportsEarMode else { return }
		let isNear = UIDevice.current.proximityState

		if isNear {
			guard voiceRecorder.state != .recording else { return }
			guard !voiceRecorder.isProcessing else { return }
			guard recordingTrigger == nil else { return }
			startRecording(trigger: .proximity, announceBeforeStart: false)
		} else {
			guard recordingTrigger == .proximity else { return }
			stopRecording(silent: false)
		}
	}

	private func makeHoldToTalkGesture(hasName: Bool) -> some Gesture {
		DragGesture(minimumDistance: 0, coordinateSpace: .local)
			.onChanged { value in
				guard !viewModel.isSending, hasName else { return }

				if !isHoldingToTalk {
					isHoldingToTalk = true
					playHaptic(times: 1, style: .heavy, intensity: 1.0)
				}

				if voiceRecorder.state != .recording, holdToTalkStartTask == nil, !isHoldToTalkLocked, !voiceRecorder.isProcessing {
					holdToTalkStartTask = Task { @MainActor in
						try? await Task.sleep(nanoseconds: 200_000_000)
						guard !Task.isCancelled else { return }
						guard isHoldingToTalk else { return }
						guard voiceRecorder.state != .recording else { return }
						guard !voiceRecorder.isProcessing else { return }
						startRecording(trigger: .holdToTalk, announceBeforeStart: false)
						holdToTalkStartTask = nil
					}
				}

				guard !isHoldToTalkLocked else { return }
				guard voiceRecorder.state == .recording, recordingTrigger == .holdToTalk else { return }
				if value.translation.height <= -120 {
					isHoldToTalkLocked = true
					playHaptic(times: 1, style: .heavy, intensity: 1.0)
					if UIAccessibility.isVoiceOverRunning {
						UIAccessibility.post(notification: .announcement, argument: "Nagrywanie zablokowane")
					}
				}
			}
			.onEnded { _ in
				isHoldingToTalk = false
				holdToTalkStartTask?.cancel()
				holdToTalkStartTask = nil

				guard recordingTrigger == .holdToTalk else { return }
				if voiceRecorder.state == .recording {
					guard !isHoldToTalkLocked else { return }
					stopRecording(silent: false)
				} else {
					startRecordingTask?.cancel()
					startRecordingTask = nil
					recordingTrigger = nil
				}
			}
	}

	private func holdToTalkVisualLabel(isRecording: Bool) -> String {
		if isHoldToTalkLocked, recordingTrigger == .holdToTalk, isRecording {
			return "Nagrywanie zablokowane"
		}
		if !isRecording, voiceRecorder.state == .recorded || voiceRecorder.state == .playingPreview {
			return "Przytrzymaj i dograj"
		}
		return "Przytrzymaj i mów"
	}

	private func holdToTalkAccessibilityLabel(isRecording: Bool) -> String {
		if isHoldToTalkLocked, recordingTrigger == .holdToTalk, isRecording {
			return "Nagrywanie zablokowane"
		}
		if !isRecording, voiceRecorder.state == .recorded || voiceRecorder.state == .playingPreview {
			return "Przytrzymaj i dograj"
		}
		return "Przytrzymaj i mów"
	}

	private func recordingStatusText(isRecording: Bool, isProcessing: Bool) -> String {
		if isProcessing {
			return "Przygotowywanie nagrania…"
		}
		if isRecording {
			return "Nagrywanie… \(formatTime(voiceRecorder.elapsedTime))"
		}
		if voiceRecorder.state == .recorded || voiceRecorder.state == .playingPreview {
			return "Nagranie gotowe. Możesz dograć."
		}
		return "Gotowe do nagrywania"
	}

	private func formatTime(_ seconds: TimeInterval) -> String {
		guard seconds.isFinite, seconds > 0 else { return "00:00" }
		let total = Int(seconds.rounded(.down))
		let m = total / 60
		let s = total % 60
		return String(format: "%02d:%02d", m, s)
	}

	private func waitForVoiceOverAnnouncementToFinish(_ announcement: String) async {
		guard UIAccessibility.isVoiceOverRunning else { return }
		do {
			try await withTimeout(5) {
				for await notification in NotificationCenter.default.notifications(named: UIAccessibility.announcementDidFinishNotification) {
					guard !Task.isCancelled else { return }
					let finishedAnnouncement = notification.userInfo?[UIAccessibility.announcementStringValueUserInfoKey] as? String
					guard finishedAnnouncement == announcement else { continue }
					return
				}
			}
		} catch {
			// Best-effort: if we can't observe completion, continue after timeout.
		}
	}

	private func playHaptic(times: Int, style: UIImpactFeedbackGenerator.FeedbackStyle = .medium, intensity: CGFloat = 1.0) {
		guard times > 0 else { return }
		let generator = UIImpactFeedbackGenerator(style: style)
		generator.prepare()
		generator.impactOccurred(intensity: intensity)

		guard times > 1 else { return }
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
			generator.prepare()
			generator.impactOccurred(intensity: intensity)
		}
	}

	private func handleAudioSessionInterruption(_ notification: Notification) {
		guard voiceRecorder.state == .recording || startRecordingTask != nil else { return }
		guard let userInfo = notification.userInfo,
		      let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
		      let type = AVAudioSession.InterruptionType(rawValue: typeValue)
		else { return }

		switch type {
		case .began:
			stopRecording(silent: true)
		case .ended:
			// Never auto-resume after a call interruption.
			break
		@unknown default:
			break
		}
	}

	private func handleEscape() {
		if voiceRecorder.state == .recording {
			stopRecording(silent: false)
			return
		}
		guard !isEarModeEnabled else { return }
		dismiss()
	}
}
