//
//  TyfloAPI.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 19/10/2022.
//

import Foundation

final class TyfloAPI: ObservableObject {
	private let session: URLSession
	private let tyfloPodcastURL = "https://tyflopodcast.net/wp-json/"
	private let tyfloWorldURL = "https://tyfloswiat.pl/wp-json/"
	static let shared = TyfloAPI()
	private init() {
		session = URLSession.shared
	}
	func getLatestPodcasts() async -> [Podcast] {
		guard let url = URL(string: tyfloPodcastURL+"wp/v2/posts?per_page=100") else {
			print("Failed to create URL")
			return [Podcast]()
		}
		do {
			let (data, _) = try await session.data(from: url)
			let decodedResponse = try JSONDecoder().decode([Podcast].self, from: data)
			return decodedResponse
		}
		catch {
			print("An error has occurred.\n\(error.localizedDescription)")
			return [Podcast]()
		}
		
	}
	func getCategories() async -> [Category] {
		guard let url = URL(string: tyfloPodcastURL+"wp/v2/categories?per_page=100") else {
			print("Failed to create a valid URL")
			return [Category]()
		}
		do {
			let (data, _) = try await session.data(from: url)
			let decodedResponse = try JSONDecoder().decode([Category].self, from: data)
			return decodedResponse
		}
		catch {
			print("An error has occurred.\n\(error.localizedDescription)")
			return [Category]()
		}
	}
	func getPodcast(for category: Category) async -> [Podcast] {
		guard let url = URL(string: tyfloPodcastURL+"wp/v2/posts?categories=\(category.id)&per_page=100") else {
			print("Failed to create URL")
			return [Podcast]()
		}
		do {
			let (data, _) = try await session.data(from: url)
			let decodedResponse = try JSONDecoder().decode([Podcast].self, from: data)
			return decodedResponse
		}
		catch {
			print("An error has occured.\n\(error.localizedDescription)")
			return [Podcast]()
		}
	}
	func getArticleCategories() async -> [Category] {
		guard let url = URL(string: tyfloWorldURL+"wp/v2/categories?per_page=100") else {
			print("Failed to create a valid URL")
			return [Category]()
		}
		do {
			let (data, _) = try await session.data(from: url)
			let decodedResponse = try JSONDecoder().decode([Category].self, from: data)
			return decodedResponse
		}
		catch {
			print("An error has occurred.\n\(error.localizedDescription)")
			return [Category]()
		}
	}
	func getArticles(for category: Category) async -> [Podcast] {
		guard let url = URL(string: tyfloWorldURL+"wp/v2/posts?categories=\(category.id)&per_page=100") else {
			print("Failed to create URL")
			return [Podcast]()
		}
		do {
			let (data, _) = try await session.data(from: url)
			let decodedResponse = try JSONDecoder().decode([Podcast].self, from: data)
			return decodedResponse
		}
		catch {
			print("An error has occured.\n\(error.localizedDescription)")
			return [Podcast]()
		}
	}
	func getListenableURL(for podcast: Podcast) -> URL {
		guard let url = URL(string: "https://tyflopodcast.net/pobierz.php?id=\(podcast.id)&plik=0") else {
			fatalError("Error")
		}
		return url
	}
	func getPodcasts(for searchString: String) async -> [Podcast] {
		guard let url = URL(string: tyfloPodcastURL+"wp/v2/posts?per_page=100&search=\(searchString)") else {
			print("Failed to create URL")
			return [Podcast]()
		}
		do {
			let (data, _) = try await session.data(from: url)
			let decodedResponse = try JSONDecoder().decode([Podcast].self, from: data)
			return decodedResponse
		}
		catch {
			print("An error has occurred.\n\(error.localizedDescription)")
			return [Podcast]()
		}
		
	}
	func getComments(for podcast: Podcast) async -> [Comment] {
		guard let url = URL(string: tyfloPodcastURL+"wp/v2/comments?post=\(podcast.id)&per_page=100") else {
			print("Error")
			return [Comment]()
		}
		do {
			let(data, _) = try await session.data(from: url)
			let decoder = JSONDecoder()
			decoder.dateDecodingStrategy = .iso8601
			decoder.keyDecodingStrategy = .convertFromSnakeCase
			let decodedResponse = try decoder.decode([Comment].self, from: data)
			return decodedResponse
		}
		catch {
			print("Error\n\(error.localizedDescription)\n\(url.absoluteString)")
			return [Comment]()
		}
	}
}
