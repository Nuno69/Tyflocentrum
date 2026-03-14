import AVFoundation
import Foundation

@MainActor
final class AudioCuePlayer {
	static let shared = AudioCuePlayer()

	private let sampleRate: Int = 44100

	private lazy var startCueData: Data = {
		let samples = Self.makeSamples(
			sampleRate: sampleRate,
			segments: [
				(.tone(frequency: 1000, amplitude: 0.25), 0.08),
				(.silence, 0.04),
				(.tone(frequency: 1000, amplitude: 0.25), 0.08),
			]
		)
		return Self.makeWAVData(samples: samples, sampleRate: sampleRate)
	}()

	private lazy var stopCueData: Data = {
		let samples = Self.makeSamples(
			sampleRate: sampleRate,
			segments: [
				(.tone(frequency: 650, amplitude: 0.25), 0.10),
			]
		)
		return Self.makeWAVData(samples: samples, sampleRate: sampleRate)
	}()

	private var player: AVAudioPlayer?

	func playStartCue() {
		play(data: startCueData)
	}

	func playStopCue() {
		play(data: stopCueData)
	}

	var startCueDurationSeconds: TimeInterval { 0.20 }
	var stopCueDurationSeconds: TimeInterval { 0.10 }

	private func play(data: Data) {
		do {
			let session = AVAudioSession.sharedInstance()
			if session.category != .playback || session.mode != .spokenAudio {
				try? session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers, .allowBluetooth])
			}
			try? session.setActive(true, options: [])

			let player = try AVAudioPlayer(data: data)
			self.player = player
			player.prepareToPlay()
			_ = player.play()
		} catch {
			// Best-effort cues; ignore failures (e.g. if audio is interrupted).
		}
	}

	private enum SegmentKind {
		case silence
		case tone(frequency: Double, amplitude: Double)
	}

	private static func makeSamples(sampleRate: Int, segments: [(SegmentKind, TimeInterval)]) -> [Int16] {
		var result: [Int16] = []
		let totalDuration = segments.reduce(0.0) { $0 + $1.1 }
		result.reserveCapacity(Int((Double(sampleRate) * totalDuration).rounded(.up)))

		for (kind, duration) in segments {
			let sampleCount = max(0, Int((Double(sampleRate) * duration).rounded()))
			switch kind {
			case .silence:
				result.append(contentsOf: repeatElement(Int16(0), count: sampleCount))
			case let .tone(frequency, amplitude):
				let clampedAmplitude = max(0.0, min(1.0, amplitude))
				let maxInt16 = Double(Int16.max)
				for i in 0 ..< sampleCount {
					let t = Double(i) / Double(sampleRate)
					let value = sin(2.0 * Double.pi * frequency * t) * (maxInt16 * clampedAmplitude)
					result.append(Int16(value))
				}
			}
		}

		return result
	}

	private static func makeWAVData(samples: [Int16], sampleRate: Int) -> Data {
		let channels: UInt16 = 1
		let bitsPerSample: UInt16 = 16
		let blockAlign = channels * (bitsPerSample / 8)
		let byteRate = UInt32(sampleRate) * UInt32(blockAlign)
		let dataSize = UInt32(samples.count) * UInt32(blockAlign)
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

		for sample in samples {
			data.appendUInt16LE(UInt16(bitPattern: sample))
		}

		return data
	}
}

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
