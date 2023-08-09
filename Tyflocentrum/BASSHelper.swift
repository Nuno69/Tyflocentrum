//
//  BASSHelper.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 17/11/2022.
//

import Foundation
import SwiftUI

final class BassHelper: ObservableObject {
	private var handles = [HSTREAM]()
	@Published private(set) var isPlaying = false
	private init() {
		BASS_SetConfig(UInt32(BASS_CONFIG_IOS_SESSION), UInt32(BASS_IOS_SESSION_DISABLE))
		let result = BASS_Init(-1, 44100, 0, nil, nil)
1		print("\(result) został zwrócony")
	}
	private func createHandle(from url: URL) -> HSTREAM? {
		let pointer = url.absoluteString.pointer
		let handle = BASS_StreamCreateURL(pointer, 0, 0, nil, nil)
		if handle == 0 {
			return nil
		}
		handles.append(handle)
		return handle
	}
	func isPlaying(handle: HSTREAM) -> Bool {
		if BASS_ChannelIsActive(handle) == BASS_ACTIVE_PLAYING {
			return true
		}
		return false
	}
	func isPlayBackActive() -> Bool {
		if BASS_IsStarted() == 1 {
			return true
		}
		return false
	}
	func togglePlayBack(for handle: HSTREAM) {
		if (isPlaying(handle: handle)) {
			if BASS_ChannelPause(handle) == 1 {
				isPlaying = false
			}
		}
		if BASS_ChannelPlay(handle, 0) == 1 {
			isPlaying = true
		}
	}
	func stopAll() {
		guard !handles.isEmpty else {
			return
		}
		for handle in handles {
			BASS_ChannelStop(handle)
			//deleteHandle(handle)
		}
	}
	func play(url: URL, overriding: Bool = true) -> HSTREAM {
		guard let handle = createHandle(from: url) else {
			return 0
		}
		if overriding {
			stopAll()
		}
		togglePlayBack(for: handle)
		return handle
	}
	func deleteHandle(_ handle: HSTREAM) {
		guard let index = handles.firstIndex(of: handle) else {
			return
		}
		BASS_ChannelFree(handle)
		handles.remove(at: index)
	}
	func pause(_ handle: HSTREAM) {
		if BASS_ChannelPause(handle) == 1 {
			isPlaying = false
		}
	}
	func resume(_ handle: HSTREAM) {
		if BASS_ChannelPlay(handle, 0) == 1{
			isPlaying = true
		}
	}
	static let shared = BassHelper()
}
