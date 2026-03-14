//
//  TyflocentrumApp.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 02/10/2022.
//

import Foundation
import SwiftUI
import UIKit
import UserNotifications

@main
struct TyflocentrumApp: App {
	private let isUITesting: Bool

	@UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

	@StateObject private var dataController: DataController
	@StateObject private var api: TyfloAPI
	@StateObject private var audioPlayer: AudioPlayer
	@StateObject private var favoritesStore: FavoritesStore
	@StateObject private var settingsStore: SettingsStore
	@StateObject private var magicTapCoordinator = MagicTapCoordinator()
	@StateObject private var pushNotifications = PushNotificationsManager()

	init() {
		let isUITesting = ProcessInfo.processInfo.arguments.contains("UI_TESTING")
		self.isUITesting = isUITesting
		_dataController = StateObject(wrappedValue: DataController(inMemory: isUITesting))
		_api = StateObject(wrappedValue: isUITesting ? TyfloAPI(session: Self.makeUITestSession()) : TyfloAPI.shared)
		if isUITesting {
			let suiteName = "TyflocentrumUITests"
			let defaults = UserDefaults(suiteName: suiteName)!
			defaults.removePersistentDomain(forName: suiteName)
			let settings = SettingsStore(userDefaults: defaults)
			_settingsStore = StateObject(wrappedValue: settings)
			_audioPlayer = StateObject(
				wrappedValue: AudioPlayer(
					userDefaults: defaults,
					playbackRateModeProvider: { settings.playbackRateRememberMode }
				)
			)
			_favoritesStore = StateObject(wrappedValue: FavoritesStore(userDefaults: defaults))
		} else {
			let settings = SettingsStore()
			_settingsStore = StateObject(wrappedValue: settings)
			_audioPlayer = StateObject(wrappedValue: AudioPlayer(playbackRateModeProvider: { settings.playbackRateRememberMode }))
			_favoritesStore = StateObject(wrappedValue: FavoritesStore())
		}
	}

	var body: some Scene {
		WindowGroup {
			MagicTapHostingView(
				rootView: ContentView()
					.environment(\.managedObjectContext, dataController.container.viewContext)
					.environmentObject(api)
					.environmentObject(audioPlayer)
					.environmentObject(favoritesStore)
					.environmentObject(settingsStore)
					.environmentObject(pushNotifications)
					.environmentObject(magicTapCoordinator),
				onMagicTap: {
					magicTapCoordinator.perform {
						audioPlayer.toggleCurrentPlayback()
					}
				}
			)
			.onAppear {
				appDelegate.pushNotifications = pushNotifications
			}
			.task {
				guard !isUITesting else { return }
				await pushNotifications.refreshAuthorizationStatus()
			}
			#if DEBUG
			.onChange(of: settingsStore.pushNotificationPreferences) { prefs in
					guard !isUITesting else { return }
					Task {
						await pushNotifications.onPreferencesChanged(prefs: prefs)
					}
				}
			#endif
		}
	}

	private static func makeUITestSession() -> URLSession {
		let config = URLSessionConfiguration.ephemeral
		config.protocolClasses = [UITestURLProtocol.self]
		return URLSession(configuration: config)
	}
}

final class AppDelegate: NSObject, UIApplicationDelegate {
	weak var pushNotifications: PushNotificationsManager?

	func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
		Task { @MainActor in
			pushNotifications?.didRegisterForRemoteNotifications(deviceToken: deviceToken)
		}
	}

	func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
		Task { @MainActor in
			pushNotifications?.didFailToRegisterForRemoteNotifications(error: error)
		}
	}
}

@MainActor
final class PushNotificationsManager: ObservableObject {
	private nonisolated static let defaultPushServiceBaseURL = URL(string: "https://tyflocentrum.tyflo.eu.org")!
	private nonisolated static let defaultRequestTimeoutSeconds: TimeInterval = 10

	private let pushServiceBaseURL: URL
	private let session: URLSession
	private let userDefaults: UserDefaults
	private let installationIDKey: String
	private var lastKnownPrefs: PushNotificationPreferences = .init()
	private var cachedInstallationID: String?

	private(set) var hasRequestedSystemPermission = false

	@Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
	@Published private(set) var deviceTokenHex: String?
	@Published private(set) var lastRegistrationError: String?
	@Published private(set) var lastServerSyncAt: Date?
	@Published private(set) var lastServerSyncError: String?
	@Published private(set) var lastServerSyncTokenKind: String?

	init(
		pushServiceBaseURL: URL = PushNotificationsManager.defaultPushServiceBaseURL,
		session: URLSession = PushNotificationsManager.makeSharedSession(),
		userDefaults: UserDefaults = .standard,
		installationIDKey: String = "push.installationID"
	) {
		self.pushServiceBaseURL = pushServiceBaseURL
		self.session = session
		self.userDefaults = userDefaults
		self.installationIDKey = installationIDKey
	}

	func onAppLaunch(prefs: PushNotificationPreferences) async {
		lastKnownPrefs = prefs
		await refreshAuthorizationStatus()
		await requestSystemPermissionIfNeeded(prefs: prefs)
		await syncRegistrationIfPossible(prefs: prefs)
	}

	func onPreferencesChanged(prefs: PushNotificationPreferences) async {
		lastKnownPrefs = prefs
		await requestSystemPermissionIfNeeded(prefs: prefs)
		await syncRegistrationIfPossible(prefs: prefs)
	}

	func refreshAuthorizationStatus() async {
		let settings = await UNUserNotificationCenter.current().notificationSettings()
		authorizationStatus = settings.authorizationStatus
	}

	private func requestSystemPermissionIfNeeded(prefs: PushNotificationPreferences) async {
		guard prefs.podcast || prefs.article || prefs.live || prefs.schedule else { return }

		let settings = await UNUserNotificationCenter.current().notificationSettings()
		authorizationStatus = settings.authorizationStatus

		switch settings.authorizationStatus {
		case .notDetermined:
			guard !hasRequestedSystemPermission else { return }
			hasRequestedSystemPermission = true
			do {
				_ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
			} catch {
				lastRegistrationError = error.localizedDescription
			}
			await refreshAuthorizationStatus()
			if authorizationStatus == .authorized || authorizationStatus == .provisional || authorizationStatus == .ephemeral {
				registerForRemoteNotifications()
			}
		case .authorized, .provisional, .ephemeral:
			registerForRemoteNotifications()
		case .denied:
			break
		@unknown default:
			break
		}
	}

	private func registerForRemoteNotifications() {
		UIApplication.shared.registerForRemoteNotifications()
	}

	func didRegisterForRemoteNotifications(deviceToken: Data) {
		deviceTokenHex = deviceToken.map { String(format: "%02x", $0) }.joined()
		lastRegistrationError = nil
		Task {
			await syncRegistrationIfPossible(prefs: lastKnownPrefs)
		}
	}

	func didFailToRegisterForRemoteNotifications(error: Error) {
		lastRegistrationError = error.localizedDescription
		Task {
			await syncRegistrationIfPossible(prefs: lastKnownPrefs)
		}
	}

	func syncRegistrationIfPossible(prefs: PushNotificationPreferences) async {
		let anyEnabled = prefs.podcast || prefs.article || prefs.live || prefs.schedule
		let token: String
		let env: String
		if let deviceTokenHex {
			token = deviceTokenHex
			env = "ios-apns"
		} else {
			env = "ios-installation"
			if anyEnabled {
				// Without Apple Developer Program / proper entitlements we may not receive an APNs token.
				// We still register an installation ID so we can validate end-to-end fan-out and server logic.
				token = getOrCreateInstallationID()
			} else if let existing = existingInstallationID() {
				token = existing
			} else {
				return
			}
		}

		do {
			if anyEnabled {
				try await registerTokenOnServer(token: token, env: env, prefs: prefs)
			} else {
				try await unregisterTokenOnServer(token: token)
			}
			lastServerSyncAt = Date()
			lastServerSyncError = nil
			lastServerSyncTokenKind = env
		} catch {
			lastServerSyncError = error.localizedDescription
		}
	}

	private func existingInstallationID() -> String? {
		let existing = userDefaults.string(forKey: installationIDKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
		return existing.isEmpty ? nil : existing
	}

	private func getOrCreateInstallationID() -> String {
		if let cachedInstallationID {
			return cachedInstallationID
		}
		if let existing = existingInstallationID() {
			cachedInstallationID = existing
			return existing
		}
		let generated = UUID().uuidString
		userDefaults.set(generated, forKey: installationIDKey)
		cachedInstallationID = generated
		return generated
	}

	private nonisolated static func makeSharedSession() -> URLSession {
		let config = URLSessionConfiguration.default
		config.waitsForConnectivity = true
		config.timeoutIntervalForRequest = defaultRequestTimeoutSeconds
		config.timeoutIntervalForResource = defaultRequestTimeoutSeconds
		return URLSession(configuration: config)
	}

	private func registerTokenOnServer(token: String, env: String, prefs: PushNotificationPreferences) async throws {
		let url = pushServiceBaseURL.appendingPathComponent("api/v1/register")

		struct RegisterBody: Encodable {
			let token: String
			let env: String
			let prefs: PushNotificationPreferences
		}

		let body = RegisterBody(token: token, env: env, prefs: prefs)
		let encoder = JSONEncoder()
		let data = try encoder.encode(body)

		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.cachePolicy = .reloadIgnoringLocalCacheData
		request.timeoutInterval = Self.defaultRequestTimeoutSeconds
		request.setValue("application/json", forHTTPHeaderField: "Accept")
		request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
		request.httpBody = data

		let (_, response) = try await session.data(for: request)
		guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
			throw URLError(.badServerResponse)
		}
	}

	private func unregisterTokenOnServer(token: String) async throws {
		let url = pushServiceBaseURL.appendingPathComponent("api/v1/unregister")

		struct UnregisterBody: Encodable {
			let token: String
		}

		let body = UnregisterBody(token: token)
		let encoder = JSONEncoder()
		let data = try encoder.encode(body)

		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.cachePolicy = .reloadIgnoringLocalCacheData
		request.timeoutInterval = Self.defaultRequestTimeoutSeconds
		request.setValue("application/json", forHTTPHeaderField: "Accept")
		request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
		request.httpBody = data

		let (_, response) = try await session.data(for: request)
		guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
			throw URLError(.badServerResponse)
		}
	}
}

@MainActor
final class MagicTapCoordinator: ObservableObject {
	private var handlers: [(id: UUID, handler: () -> Bool)] = []

	func push(_ handler: @escaping () -> Bool) -> UUID {
		let id = UUID()
		handlers.append((id: id, handler: handler))
		return id
	}

	func remove(_ id: UUID) {
		handlers.removeAll { $0.id == id }
	}

	func perform(_ defaultHandler: () -> Bool) -> Bool {
		if let top = handlers.last {
			let didHandle = top.handler()
			if didHandle {
				return true
			}
		}
		return defaultHandler()
	}
}

@MainActor
final class MagicTapHostingController<Content: View>: UIHostingController<Content> {
	var onMagicTap: (() -> Bool)?

	override func accessibilityPerformMagicTap() -> Bool {
		onMagicTap?() ?? false
	}
}

struct MagicTapHostingView<Content: View>: UIViewControllerRepresentable {
	let rootView: Content
	let onMagicTap: () -> Bool

	func makeUIViewController(context _: Context) -> MagicTapHostingController<Content> {
		let controller = MagicTapHostingController(rootView: rootView)
		controller.onMagicTap = onMagicTap
		return controller
	}

	func updateUIViewController(_ uiViewController: MagicTapHostingController<Content>, context _: Context) {
		uiViewController.onMagicTap = onMagicTap
	}
}

private final class UITestURLProtocol: URLProtocol {
	private static let stateLock = NSLock()
	private static var tyflopodcastLatestPostsRequestCount = 0
	private static var tyflopodcastCategoryPostsRequestCount = 0
	private static var tyflopodcastCategoriesRequestCount = 0
	private static var tyflopodcastSearchPostsRequestCount = 0
	private static var tyfloswiatCategoriesRequestCount = 0
	private static var tyfloswiatCategoryPostsRequestCount = 0
	private static var tyfloswiatSearchPostsRequestCount = 0
	private static var stalledNewsRequestsCount = 0
	private static var stalledDetailRequestsCount = 0

	private static var didFailTyflopodcastLatestPosts = false
	private static var didFailTyflopodcastCategoryPosts = false
	private static var didFailTyflopodcastCategories = false
	private static var didFailTyflopodcastSearchPosts = false
	private static var didFailTyfloswiatCategories = false
	private static var didFailTyfloswiatCategoryPosts = false
	private static var didFailTyfloswiatSearchPosts = false
	private static var didFailTyfloswiatLatestPosts = false
	private static var didFailTyflopodcastPostDetails = false
	private static var didFailTyfloswiatPostDetails = false
	private static var didFailTyfloswiatPageDetails = false

	private var didCompleteLoading = false

	override class func canInit(with _: URLRequest) -> Bool {
		true
	}

	override class func canonicalRequest(for request: URLRequest) -> URLRequest {
		request
	}

	override func startLoading() {
		guard let url = request.url else {
			client?.urlProtocol(self, didFailWithError: URLError(.badURL))
			return
		}

		if Self.shouldStallNewsRequests(for: request) {
			return
		}
		if Self.shouldStallDetailRequests(for: request) {
			return
		}

		let (statusCode, data) = Self.response(for: request)
		let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
		client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
		client?.urlProtocol(self, didLoad: data)
		client?.urlProtocolDidFinishLoading(self)
		didCompleteLoading = true
	}

	override func stopLoading() {
		guard !didCompleteLoading else { return }
		client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
	}

	private static func shouldStallNewsRequests(for request: URLRequest) -> Bool {
		guard isFlagEnabled("UI_TESTING_STALL_NEWS_REQUESTS") else { return false }
		guard let url = request.url else { return false }

		guard url.path.contains("/wp-json/wp/v2/posts") else { return false }
		guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
		guard let queryItems = components.queryItems else { return false }
		guard queryItems.contains(where: { $0.name == "context" && $0.value == "embed" }) else { return false }

		stateLock.lock()
		defer { stateLock.unlock() }

		guard stalledNewsRequestsCount < 2 else { return false }
		stalledNewsRequestsCount += 1
		return true
	}

	private static func shouldStallDetailRequests(for request: URLRequest) -> Bool {
		guard isFlagEnabled("UI_TESTING_STALL_DETAIL_REQUESTS") else { return false }
		guard let url = request.url else { return false }

		let isPostDetailRequest = url.path.contains("/wp-json/wp/v2/posts/") && Int(url.lastPathComponent) != nil
		let isPageDetailRequest = url.path.contains("/wp-json/wp/v2/pages/") && Int(url.lastPathComponent) != nil
		guard isPostDetailRequest || isPageDetailRequest else { return false }

		stateLock.lock()
		defer { stateLock.unlock() }

		guard stalledDetailRequestsCount < 1 else { return false }
		stalledDetailRequestsCount += 1
		return true
	}

	private static func response(for request: URLRequest) -> (Int, Data) {
		guard let url = request.url else { return (400, Data()) }

		if url.host == "tyflopodcast.net", url.path.contains("/wp-json/wp/v2/categories") {
			if shouldFailOnce(&didFailTyflopodcastCategories) {
				return (500, Data("[]".utf8))
			}
			let requestIndex = nextRequestIndex(for: &tyflopodcastCategoriesRequestCount)
			if requestIndex <= 1 {
				return (200, #"[{"id":10,"name":"Test podcasty","count":1}]"#.data(using: .utf8) ?? Data("[]".utf8))
			}
			return (
				200,
				#"[{"id":10,"name":"Test podcasty","count":1},{"id":11,"name":"Test podcasty 2","count":1}]"#.data(using: .utf8) ?? Data("[]".utf8)
			)
		}

		if url.host == "tyfloswiat.pl", url.path.contains("/wp-json/wp/v2/categories") {
			if shouldFailOnce(&didFailTyfloswiatCategories) {
				return (500, Data("[]".utf8))
			}
			let requestIndex = nextRequestIndex(for: &tyfloswiatCategoriesRequestCount)
			if requestIndex <= 1 {
				return (200, #"[{"id":20,"name":"Test artykuły","count":1}]"#.data(using: .utf8) ?? Data("[]".utf8))
			}
			return (
				200,
				#"[{"id":20,"name":"Test artykuły","count":1},{"id":21,"name":"Test artykuły 2","count":1}]"#.data(using: .utf8) ?? Data("[]".utf8)
			)
		}

		if url.host == "tyfloswiat.pl", url.path.contains("/wp-json/wp/v2/pages") {
			if let pageID = Int(url.lastPathComponent), url.path.contains("/wp-json/wp/v2/pages/") {
				let shouldFail = shouldFailOnce(&didFailTyfloswiatPageDetails, whenFlagEnabled: "UI_TESTING_FAIL_FIRST_DETAIL_REQUEST")
				if isFlagEnabled("UI_TESTING_FAIL_FIRST_DETAIL_REQUEST") {
					AppLog.uiTests.debug("tyfloswiat page detail id=\(pageID) shouldFail=\(shouldFail)")
				}
				if shouldFail {
					return (500, Data("{}".utf8))
				}
				if pageID == 7772 {
					return (
						200,
						#"""
							{"id":7772,"date":"2025-08-20T12:16:01","title":{"rendered":"Tyfloświat 4/2025"},"excerpt":{"rendered":"Excerpt"},"content":{"rendered":"<h2>Spis treści</h2><ul><li><a href='https://tyfloswiat.pl/czasopismo/tyfloswiat-4-2025/test-article-1/'>Test artykuł 1</a></li></ul><p>Pobierz PDF – <a href='https://tyfloswiat.pl/wp-content/uploads/2025/08/Tyflo-4_2025.pdf'>Tyflo 4_2025</a></p>"},"guid":{"rendered":"https://tyfloswiat.pl/?page_id=7772"}}
						"""#.data(using: .utf8) ?? Data()
					)
				}

				if pageID == 7774 {
					return (
						200,
						#"""
						{"id":7774,"date":"2025-08-20T12:16:01","title":{"rendered":"Test artykuł 1"},"excerpt":{"rendered":"Excerpt"},"content":{"rendered":"Content"},"guid":{"rendered":"https://tyfloswiat.pl/?page_id=7774"}}
						"""#.data(using: .utf8) ?? Data()
					)
				}

				return (
					200,
					#"""
					{"id":\#(pageID),"date":"2026-01-20T00:59:40","title":{"rendered":"Test strona"},"excerpt":{"rendered":"Excerpt"},"content":{"rendered":"Content"},"guid":{"rendered":"https://tyfloswiat.pl/?page_id=\#(pageID)"}}
					"""#.data(using: .utf8) ?? Data()
				)
			}

			let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
			let queryItems = components?.queryItems ?? []

			if queryItems.contains(where: { $0.name == "slug" && $0.value == "czasopismo" }) {
				return (
					200,
					#"[{"id":1409,"date":"2020-04-01T07:58:32","title":{"rendered":"Czasopismo Tyfloświat"},"excerpt":{"rendered":""},"link":"https://tyfloswiat.pl/czasopismo/"}]"#.data(using: .utf8) ?? Data("[]".utf8)
				)
			}

			if queryItems.contains(where: { $0.name == "parent" && $0.value == "1409" }) {
				return (
					200,
					#"[{"id":7772,"date":"2025-08-20T12:16:01","title":{"rendered":"Tyfloświat 4/2025"},"excerpt":{"rendered":"Excerpt"},"link":"https://tyfloswiat.pl/czasopismo/tyfloswiat-4-2025/"}]"#.data(using: .utf8) ?? Data("[]".utf8)
				)
			}

			if queryItems.contains(where: { $0.name == "parent" }) {
				return (
					200,
					#"[{"id":7774,"date":"2025-08-20T12:16:01","title":{"rendered":"Test artykuł 1"},"excerpt":{"rendered":"Excerpt"},"link":"https://tyfloswiat.pl/czasopismo/tyfloswiat-4-2025/test-article-1/"}]"#.data(using: .utf8) ?? Data("[]".utf8)
				)
			}

			return (200, Data("[]".utf8))
		}

		if url.host == "tyflopodcast.net", url.path.contains("/wp-json/wp/v2/posts") {
			if let postID = Int(url.lastPathComponent), url.path.contains("/wp-json/wp/v2/posts/") {
				let shouldFail = shouldFailOnce(&didFailTyflopodcastPostDetails, whenFlagEnabled: "UI_TESTING_FAIL_FIRST_DETAIL_REQUEST")
				if isFlagEnabled("UI_TESTING_FAIL_FIRST_DETAIL_REQUEST") {
					AppLog.uiTests.debug("tyflopodcast post detail id=\(postID) shouldFail=\(shouldFail)")
				}
				if shouldFail {
					return (500, Data("{}".utf8))
				}
				return (
					200,
					#"""
						{"id":\#(postID),"date":"2026-01-20T00:59:40","title":{"rendered":"Test podcast"},"excerpt":{"rendered":"Excerpt"},"content":{"rendered":"Content"},"guid":{"rendered":"https://tyflopodcast.net/?p=\#(postID)"},"link":"https://tyflopodcast.net/?p=\#(postID)"}
					"""#.data(using: .utf8) ?? Data()
				)
			}

			let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
			let queryItems = components?.queryItems ?? []

			if queryItems.contains(where: { $0.name == "search" }) {
				if shouldFailOnce(&didFailTyflopodcastSearchPosts) {
					return (500, Data("[]".utf8))
				}
				let requestIndex = nextRequestIndex(for: &tyflopodcastSearchPostsRequestCount)
				if requestIndex <= 1 {
					return (
						200,
						#"[{"id":1,"date":"2026-01-20T00:59:40","title":{"rendered":"Test podcast"},"excerpt":{"rendered":"Excerpt"},"content":{"rendered":"Content"},"guid":{"rendered":"https://tyflopodcast.net/?p=1"},"link":"https://tyflopodcast.net/?p=1"}]"#.data(using: .utf8) ?? Data("[]".utf8)
					)
				}
				return (
					200,
					#"[{"id":1,"date":"2026-01-20T00:59:40","title":{"rendered":"Test podcast"},"excerpt":{"rendered":"Excerpt"},"content":{"rendered":"Content"},"guid":{"rendered":"https://tyflopodcast.net/?p=1"},"link":"https://tyflopodcast.net/?p=1"},{"id":6,"date":"2026-01-21T00:59:40","title":{"rendered":"Test podcast wynik 2"},"excerpt":{"rendered":"Excerpt"},"content":{"rendered":"Content"},"guid":{"rendered":"https://tyflopodcast.net/?p=6"},"link":"https://tyflopodcast.net/?p=6"}]"#.data(using: .utf8) ?? Data("[]".utf8)
				)
			}

			if queryItems.contains(where: { $0.name == "categories" }) {
				if shouldFailOnce(&didFailTyflopodcastCategoryPosts) {
					return (500, Data("[]".utf8))
				}
				let requestIndex = nextRequestIndex(for: &tyflopodcastCategoryPostsRequestCount)
				if requestIndex <= 1 {
					return (
						200,
						#"[{"id":1,"date":"2026-01-20T00:59:40","title":{"rendered":"Test podcast"},"excerpt":{"rendered":"Excerpt"},"content":{"rendered":"Content"},"guid":{"rendered":"https://tyflopodcast.net/?p=1"},"link":"https://tyflopodcast.net/?p=1"}]"#.data(using: .utf8) ?? Data("[]".utf8)
					)
				}

				return (
					200,
					#"[{"id":1,"date":"2026-01-20T00:59:40","title":{"rendered":"Test podcast"},"excerpt":{"rendered":"Excerpt"},"content":{"rendered":"Content"},"guid":{"rendered":"https://tyflopodcast.net/?p=1"},"link":"https://tyflopodcast.net/?p=1"},{"id":4,"date":"2026-01-21T00:59:40","title":{"rendered":"Test podcast w kategorii 2"},"excerpt":{"rendered":"Excerpt"},"content":{"rendered":"Content"},"guid":{"rendered":"https://tyflopodcast.net/?p=4"},"link":"https://tyflopodcast.net/?p=4"}]"#.data(using: .utf8) ?? Data("[]".utf8)
				)
			}

			if shouldFailOnce(&didFailTyflopodcastLatestPosts) {
				return (500, Data("[]".utf8))
			}
			_ = nextRequestIndex(for: &tyflopodcastLatestPostsRequestCount)

			return (
				200,
				#"[{"id":1,"date":"2026-01-20T00:59:40","title":{"rendered":"Test podcast"},"excerpt":{"rendered":"Excerpt"},"content":{"rendered":"Content"},"guid":{"rendered":"https://tyflopodcast.net/?p=1"},"link":"https://tyflopodcast.net/?p=1"},{"id":3,"date":"2026-01-21T00:59:40","title":{"rendered":"Test podcast 2"},"excerpt":{"rendered":"Excerpt"},"content":{"rendered":"Content"},"guid":{"rendered":"https://tyflopodcast.net/?p=3"},"link":"https://tyflopodcast.net/?p=3"}]"#.data(using: .utf8) ?? Data("[]".utf8)
			)
		}

		if url.host == "tyfloswiat.pl", url.path.contains("/wp-json/wp/v2/posts") {
			if let postID = Int(url.lastPathComponent), url.path.contains("/wp-json/wp/v2/posts/") {
				let shouldFail = shouldFailOnce(&didFailTyfloswiatPostDetails, whenFlagEnabled: "UI_TESTING_FAIL_FIRST_DETAIL_REQUEST")
				if isFlagEnabled("UI_TESTING_FAIL_FIRST_DETAIL_REQUEST") {
					AppLog.uiTests.debug("tyfloswiat post detail id=\(postID) shouldFail=\(shouldFail)")
				}
				if shouldFail {
					return (500, Data("{}".utf8))
				}
				return (
					200,
					#"""
						{"id":\#(postID),"date":"2026-01-20T00:59:40","title":{"rendered":"Test artykuł"},"excerpt":{"rendered":"Excerpt"},"content":{"rendered":"Content"},"guid":{"rendered":"https://tyfloswiat.pl/?p=\#(postID)"},"link":"https://tyfloswiat.pl/?p=\#(postID)"}
					"""#.data(using: .utf8) ?? Data()
				)
			}

			let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
			let queryItems = components?.queryItems ?? []

			if queryItems.contains(where: { $0.name == "search" }) {
				if shouldFailOnce(&didFailTyfloswiatSearchPosts) {
					return (500, Data("[]".utf8))
				}

				let requestIndex = nextRequestIndex(for: &tyfloswiatSearchPostsRequestCount)
				if requestIndex <= 1 {
					return (
						200,
						#"[{"id":2,"date":"2026-01-20T00:59:40","title":{"rendered":"Test artykuł"},"excerpt":{"rendered":"Excerpt"},"content":{"rendered":"Content"},"guid":{"rendered":"https://tyfloswiat.pl/?p=2"},"link":"https://tyfloswiat.pl/?p=2"}]"#.data(using: .utf8) ?? Data("[]".utf8)
					)
				}

				return (
					200,
					#"[{"id":2,"date":"2026-01-20T00:59:40","title":{"rendered":"Test artykuł"},"excerpt":{"rendered":"Excerpt"},"content":{"rendered":"Content"},"guid":{"rendered":"https://tyfloswiat.pl/?p=2"},"link":"https://tyfloswiat.pl/?p=2"}]"#.data(using: .utf8) ?? Data("[]".utf8)
				)
			}

			if queryItems.contains(where: { $0.name == "categories" }) {
				if shouldFailOnce(&didFailTyfloswiatCategoryPosts) {
					return (500, Data("[]".utf8))
				}
				let requestIndex = nextRequestIndex(for: &tyfloswiatCategoryPostsRequestCount)
				if requestIndex <= 1 {
					return (
						200,
						#"[{"id":2,"date":"2026-01-20T00:59:40","title":{"rendered":"Test artykuł"},"excerpt":{"rendered":"Excerpt"},"content":{"rendered":"Content"},"guid":{"rendered":"https://tyfloswiat.pl/?p=2"},"link":"https://tyfloswiat.pl/?p=2"}]"#.data(using: .utf8) ?? Data("[]".utf8)
					)
				}

				return (
					200,
					#"[{"id":2,"date":"2026-01-20T00:59:40","title":{"rendered":"Test artykuł"},"excerpt":{"rendered":"Excerpt"},"content":{"rendered":"Content"},"guid":{"rendered":"https://tyfloswiat.pl/?p=2"},"link":"https://tyfloswiat.pl/?p=2"},{"id":5,"date":"2026-01-21T00:59:40","title":{"rendered":"Test artykuł 2"},"excerpt":{"rendered":"Excerpt"},"content":{"rendered":"Content"},"guid":{"rendered":"https://tyfloswiat.pl/?p=5"},"link":"https://tyfloswiat.pl/?p=5"}]"#.data(using: .utf8) ?? Data("[]".utf8)
				)
			}

			if shouldFailOnce(&didFailTyfloswiatLatestPosts) {
				return (500, Data("[]".utf8))
			}

			return (
				200,
				#"[{"id":2,"date":"2026-01-20T00:59:40","title":{"rendered":"Test artykuł"},"excerpt":{"rendered":"Excerpt"},"content":{"rendered":"Content"},"guid":{"rendered":"https://tyfloswiat.pl/?p=2"},"link":"https://tyfloswiat.pl/?p=2"}]"#.data(using: .utf8) ?? Data("[]".utf8)
			)
		}

		if url.host == "kontakt.tyflopodcast.net" {
			let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
			let action = components?.queryItems?.first(where: { $0.name == "ac" })?.value

			if action == "current" {
				if isFlagEnabled("UI_TESTING_TP_AVAILABLE") {
					return (200, #"{"available":true,"title":"Test audycja"}"#.data(using: .utf8) ?? Data())
				}
				return (200, #"{"available":false,"title":null}"#.data(using: .utf8) ?? Data())
			}

			if action == "add" {
				return (200, #"{"author":"UI","comment":"Test","error":null}"#.data(using: .utf8) ?? Data())
			}

			if action == "schedule" {
				return (
					200,
					#"{"available":true,"text":"Test ramówka\nPoniedziałek 10:00 - Audycja\nWtorek 12:00 - Audycja"}"#.data(using: .utf8) ?? Data()
				)
			}
		}

		return (200, Data("[]".utf8))
	}

	private static func isFlagEnabled(_ flag: String) -> Bool {
		ProcessInfo.processInfo.arguments.contains(flag)
	}

	private static func shouldFailOnce(_ didFail: inout Bool, whenFlagEnabled flag: String) -> Bool {
		guard isFlagEnabled(flag) else { return false }

		stateLock.lock()
		defer { stateLock.unlock() }

		if didFail {
			return false
		}
		didFail = true
		return true
	}

	private static func shouldFailOnce(_ didFail: inout Bool) -> Bool {
		shouldFailOnce(&didFail, whenFlagEnabled: "UI_TESTING_FAIL_FIRST_REQUEST")
	}

	private static func nextRequestIndex(for counter: inout Int) -> Int {
		stateLock.lock()
		defer { stateLock.unlock() }
		counter += 1
		return counter
	}
}
