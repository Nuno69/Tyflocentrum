//
//  PodcastPlayerSheet.swift
//  Tyflocentrum
//

import SwiftUI

struct PodcastPlayerView: View {
	let podcast: Podcast
	@EnvironmentObject var api: TyfloAPI

	var body: some View {
		MediaPlayerView(
			podcast: api.getListenableURL(for: podcast),
			title: podcast.title.plainText,
			subtitle: podcast.formattedDate,
			canBeLive: false,
			podcastPostID: podcast.id
		)
	}
}
