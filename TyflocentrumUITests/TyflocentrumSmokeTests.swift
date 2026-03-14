import CoreGraphics
import XCTest

final class TyflocentrumSmokeTests: XCTestCase {
	override func setUpWithError() throws {
		continueAfterFailure = false
	}

	private func makeApp(additionalLaunchArguments: [String] = []) -> XCUIApplication {
		let app = XCUIApplication()
		app.terminate()
		app.launchArguments = ["UI_TESTING"] + additionalLaunchArguments
		return app
	}

	private func pullToRefresh(_ list: XCUIElement, untilExists element: XCUIElement, scrollToReveal: Bool = false) {
		func dragDown() {
			let start = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
			let finish = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
			start.press(forDuration: 0.05, thenDragTo: finish)
		}

		dragDown()
		if !element.waitForExistence(timeout: 2) {
			dragDown()
		}
		if scrollToReveal {
			for _ in 0 ..< 2 {
				if element.waitForExistence(timeout: 0.5) { break }
				list.swipeDown()
			}
			for _ in 0 ..< 8 {
				if element.waitForExistence(timeout: 0.5) { break }
				list.swipeUp()
			}
		}
		XCTAssertTrue(element.waitForExistence(timeout: 5))
	}

	private func tapBackButton(in app: XCUIApplication) {
		let backButton = app.navigationBars.firstMatch.buttons.element(boundBy: 0)
		XCTAssertTrue(backButton.waitForExistence(timeout: 5))
		backButton.tap()
	}

	private func openFavoritesFromMenu(in app: XCUIApplication) {
		let menuQuery = app.descendants(matching: .any).matching(identifier: "app.menu")
		var menuButton = menuQuery.firstMatch

		// The app menu is available on tab root screens; on pushed detail screens we should go back first.
		if !menuButton.waitForExistence(timeout: 2) {
			let backButton = app.navigationBars.firstMatch.buttons.element(boundBy: 0)
			if backButton.waitForExistence(timeout: 2) {
				backButton.tap()
			}
		}

		menuButton = menuQuery.firstMatch
		XCTAssertTrue(menuButton.waitForExistence(timeout: 5))
		menuButton.tap()

		let favoritesButton = app.descendants(matching: .any).matching(identifier: "app.menu.favorites").firstMatch
		XCTAssertTrue(favoritesButton.waitForExistence(timeout: 5))
		favoritesButton.tap()

		let favoritesList = app.descendants(matching: .any).matching(identifier: "favorites.list").firstMatch
		XCTAssertTrue(favoritesList.waitForExistence(timeout: 5))
	}

	private func openSettingsFromMenu(in app: XCUIApplication) {
		let menuQuery = app.descendants(matching: .any).matching(identifier: "app.menu")
		var menuButton = menuQuery.firstMatch

		// The app menu is available on tab root screens; on pushed detail screens we should go back first.
		if !menuButton.waitForExistence(timeout: 2) {
			let backButton = app.navigationBars.firstMatch.buttons.element(boundBy: 0)
			if backButton.waitForExistence(timeout: 2) {
				backButton.tap()
			}
		}

		menuButton = menuQuery.firstMatch
		XCTAssertTrue(menuButton.waitForExistence(timeout: 5))
		menuButton.tap()

		let settingsButton = app.descendants(matching: .any).matching(identifier: "app.menu.settings").firstMatch
		XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
		settingsButton.tap()

		let settingsView = app.descendants(matching: .any).matching(identifier: "settings.view").firstMatch
		XCTAssertTrue(settingsView.waitForExistence(timeout: 5))
	}

	func testAppLaunchesAndShowsTabs() {
		let app = makeApp()
		app.launch()

		XCTAssertTrue(app.tabBars.buttons["Nowości"].waitForExistence(timeout: 5))
		XCTAssertTrue(app.tabBars.buttons["Podcasty"].exists)
		XCTAssertTrue(app.tabBars.buttons["Artykuły"].exists)
		XCTAssertTrue(app.tabBars.buttons["Szukaj"].exists)
		XCTAssertTrue(app.tabBars.buttons["Tyfloradio"].exists)
	}

	func testNewsShowsRetryWhenRequestsStall() {
		let app = makeApp(additionalLaunchArguments: ["UI_TESTING_STALL_NEWS_REQUESTS", "UI_TESTING_FAST_TIMEOUTS"])
		app.launch()

		app.tabBars.buttons["Nowości"].tap()

		let podcastRow = app.descendants(matching: .any).matching(identifier: "podcast.row.1").firstMatch
		XCTAssertTrue(podcastRow.waitForExistence(timeout: 10))
	}

	func testCanOpenRadioPlayerFromMoreTab() {
		let app = makeApp()
		app.launch()

		app.tabBars.buttons["Tyfloradio"].tap()

		let radioButton = app.descendants(matching: .any).matching(identifier: "more.tyfloradio").firstMatch
		XCTAssertTrue(radioButton.waitForExistence(timeout: 5))
		radioButton.tap()

		let playPauseButton = app.descendants(matching: .any).matching(identifier: "player.playPause").firstMatch
		XCTAssertTrue(playPauseButton.waitForExistence(timeout: 5))
		XCTAssertEqual(playPauseButton.label, "Odtwarzaj")

		let contactButton = app.descendants(matching: .any).matching(identifier: "player.contactRadio").firstMatch
		XCTAssertTrue(contactButton.exists)
		XCTAssertEqual(contactButton.label, "Skontaktuj się z Tyfloradiem")
	}

	func testCanOpenRadioScheduleFromMoreTab() {
		let app = makeApp()
		app.launch()

		app.tabBars.buttons["Tyfloradio"].tap()

		let scheduleButton = app.descendants(matching: .any).matching(identifier: "more.schedule").firstMatch
		XCTAssertTrue(scheduleButton.waitForExistence(timeout: 5))
		scheduleButton.tap()

		let scheduleView = app.descendants(matching: .any).matching(identifier: "radioSchedule.view").firstMatch
		XCTAssertTrue(scheduleView.waitForExistence(timeout: 5))

		let scheduleText = app.descendants(matching: .any).matching(identifier: "radioSchedule.text").firstMatch
		XCTAssertTrue(scheduleText.waitForExistence(timeout: 5))
	}

	func testCanSendVoiceMessageWhenTextMessageIsEmpty() {
		let app = makeApp(additionalLaunchArguments: ["UI_TESTING_TP_AVAILABLE", "UI_TESTING_SEED_VOICE_RECORDED", "UI_TESTING_CONTACT_MESSAGE_WHITESPACE"])
		app.launch()

		app.tabBars.buttons["Tyfloradio"].tap()

		let contactButton = app.descendants(matching: .any).matching(identifier: "more.contactRadio").firstMatch
		XCTAssertTrue(contactButton.waitForExistence(timeout: 5))
		contactButton.tap()

		let voiceMenuItem = app.descendants(matching: .any).matching(identifier: "contact.menu.voice").firstMatch
		XCTAssertTrue(voiceMenuItem.waitForExistence(timeout: 5))
		voiceMenuItem.tap()

		let nameField = app.descendants(matching: .any).matching(identifier: "contact.name").firstMatch
		XCTAssertTrue(nameField.waitForExistence(timeout: 5))
		nameField.tap()
		nameField.typeText("UI")

		let voiceSendButton = app.descendants(matching: .any).matching(identifier: "contact.voice.send").firstMatch
		let voiceForm = app.descendants(matching: .any).matching(identifier: "contactVoice.form").firstMatch
		XCTAssertTrue(voiceForm.waitForExistence(timeout: 5))
		for _ in 0 ..< 8 {
			if voiceSendButton.exists { break }
			voiceForm.swipeUp()
		}
		XCTAssertTrue(voiceSendButton.waitForExistence(timeout: 5))
		XCTAssertTrue(voiceSendButton.isEnabled)

		let backButton = app.navigationBars.buttons["Kontakt"].firstMatch
		XCTAssertTrue(backButton.waitForExistence(timeout: 5))
		backButton.tap()

		let textMenuItem = app.descendants(matching: .any).matching(identifier: "contact.menu.text").firstMatch
		XCTAssertTrue(textMenuItem.waitForExistence(timeout: 5))
		textMenuItem.tap()

		let textSendButton = app.descendants(matching: .any).matching(identifier: "contact.send").firstMatch
		XCTAssertTrue(textSendButton.waitForExistence(timeout: 5))
		XCTAssertFalse(textSendButton.isEnabled)
	}

	func testCanPreviewRecordedVoiceMessage() {
		let app = makeApp(additionalLaunchArguments: ["UI_TESTING_TP_AVAILABLE", "UI_TESTING_SEED_VOICE_RECORDED"])
		app.launch()

		app.tabBars.buttons["Tyfloradio"].tap()

		let contactButton = app.descendants(matching: .any).matching(identifier: "more.contactRadio").firstMatch
		XCTAssertTrue(contactButton.waitForExistence(timeout: 5))
		contactButton.tap()

		let voiceMenuItem = app.descendants(matching: .any).matching(identifier: "contact.menu.voice").firstMatch
		XCTAssertTrue(voiceMenuItem.waitForExistence(timeout: 5))
		voiceMenuItem.tap()

		let nameField = app.descendants(matching: .any).matching(identifier: "contact.name").firstMatch
		XCTAssertTrue(nameField.waitForExistence(timeout: 5))
		nameField.tap()
		nameField.typeText("UI")

		let holdToTalkButton = app.descendants(matching: .any).matching(identifier: "contact.voice.holdToTalk").firstMatch
		XCTAssertTrue(holdToTalkButton.waitForExistence(timeout: 5))
		XCTAssertTrue(holdToTalkButton.isEnabled)

		let previewButton = app.descendants(matching: .any).matching(identifier: "contact.voice.preview").firstMatch
		let voiceForm = app.descendants(matching: .any).matching(identifier: "contactVoice.form").firstMatch
		XCTAssertTrue(voiceForm.waitForExistence(timeout: 5))
		for _ in 0 ..< 8 {
			if previewButton.exists { break }
			voiceForm.swipeUp()
		}
		XCTAssertTrue(previewButton.waitForExistence(timeout: 5))
		XCTAssertEqual(previewButton.label, "Odsłuchaj")

		previewButton.tap()
		expectation(for: NSPredicate(format: "label == %@", "Zatrzymaj odsłuch"), evaluatedWith: previewButton)
		waitForExpectations(timeout: 5)

		previewButton.tap()
		expectation(for: NSPredicate(format: "label == %@", "Odsłuchaj"), evaluatedWith: previewButton)
		waitForExpectations(timeout: 5)
	}

	func testCanOpenPodcastPlayerAndSeeSeekControls() {
		let app = makeApp()
		app.launch()

		app.tabBars.buttons["Nowości"].tap()

		let podcastRow = app.descendants(matching: .any).matching(identifier: "podcast.row.1").firstMatch
		XCTAssertTrue(podcastRow.waitForExistence(timeout: 5))
		podcastRow.tap()

		let content = app.descendants(matching: .any).matching(identifier: "podcastDetail.content").firstMatch
		XCTAssertTrue(content.waitForExistence(timeout: 5))

		let listenButton = app.descendants(matching: .any).matching(identifier: "podcastDetail.listen").firstMatch
		XCTAssertTrue(listenButton.waitForExistence(timeout: 5))
		XCTAssertEqual(listenButton.label, "Słuchaj audycji")
		listenButton.tap()

		let playPauseButton = app.descendants(matching: .any).matching(identifier: "player.playPause").firstMatch
		XCTAssertTrue(playPauseButton.waitForExistence(timeout: 5))
		XCTAssertTrue(["Odtwarzaj", "Pauza"].contains(playPauseButton.label))

		let skipBack = app.descendants(matching: .any).matching(identifier: "player.skipBackward30").firstMatch
		XCTAssertTrue(skipBack.exists)
		XCTAssertEqual(skipBack.label, "Cofnij 30 sekund")

		let skipForward = app.descendants(matching: .any).matching(identifier: "player.skipForward30").firstMatch
		XCTAssertTrue(skipForward.exists)
		XCTAssertEqual(skipForward.label, "Przewiń do przodu 30 sekund")

		let speedButton = app.descendants(matching: .any).matching(identifier: "player.speed").firstMatch
		XCTAssertTrue(speedButton.exists)
		XCTAssertEqual(speedButton.label, "Zmień prędkość odtwarzania")

		let airPlayButton = app.descendants(matching: .any).matching(identifier: "player.airplay").firstMatch
		XCTAssertTrue(airPlayButton.waitForExistence(timeout: 5))
	}

	func testCanAddPodcastToFavoritesAndSeeItInFavorites() {
		let app = makeApp()
		app.launch()

		app.tabBars.buttons["Nowości"].tap()

		let podcastRow = app.descendants(matching: .any).matching(identifier: "podcast.row.1").firstMatch
		XCTAssertTrue(podcastRow.waitForExistence(timeout: 5))
		podcastRow.tap()

		let content = app.descendants(matching: .any).matching(identifier: "podcastDetail.content").firstMatch
		XCTAssertTrue(content.waitForExistence(timeout: 5))

		let favoriteButton = app.descendants(matching: .any).matching(identifier: "podcastDetail.favorite").firstMatch
		XCTAssertTrue(favoriteButton.waitForExistence(timeout: 5))
		XCTAssertEqual(favoriteButton.label, "Dodaj do ulubionych")
		favoriteButton.tap()

		let predicate = NSPredicate(format: "label == %@", "Usuń z ulubionych")
		let waitExpectation = expectation(for: predicate, evaluatedWith: favoriteButton)
		XCTAssertEqual(XCTWaiter().wait(for: [waitExpectation], timeout: 5), .completed)

		openFavoritesFromMenu(in: app)

		let favoritesPodcastRow = app.descendants(matching: .any).matching(identifier: "podcast.row.1").firstMatch
		XCTAssertTrue(favoritesPodcastRow.waitForExistence(timeout: 5))
		tapBackButton(in: app)
	}

	func testPodcastFavoritedFromRowCanBeUnfavoritedInDetail() {
		let app = makeApp()
		app.launch()

		app.tabBars.buttons["Nowości"].tap()

		let podcastRow = app.descendants(matching: .any).matching(identifier: "podcast.row.1").firstMatch
		XCTAssertTrue(podcastRow.waitForExistence(timeout: 5))

		podcastRow.press(forDuration: 1.0)

		let addFavoriteButton = app.buttons["Dodaj do ulubionych"].firstMatch
		let addFavoriteMenuItem = app.menuItems["Dodaj do ulubionych"].firstMatch
		let addFavoriteElement: XCUIElement
		if addFavoriteButton.waitForExistence(timeout: 2) {
			addFavoriteElement = addFavoriteButton
		} else {
			XCTAssertTrue(addFavoriteMenuItem.waitForExistence(timeout: 2))
			addFavoriteElement = addFavoriteMenuItem
		}
		addFavoriteElement.tap()

		let menuDismissPredicate = NSPredicate(format: "exists == false")
		let menuDismissExpectation = expectation(for: menuDismissPredicate, evaluatedWith: addFavoriteElement)
		XCTAssertEqual(XCTWaiter().wait(for: [menuDismissExpectation], timeout: 5), .completed)

		let podcastRowAfterFavorite = app.descendants(matching: .any).matching(identifier: "podcast.row.1").firstMatch
		XCTAssertTrue(podcastRowAfterFavorite.waitForExistence(timeout: 5))
		podcastRowAfterFavorite.tap()

		let favoriteButton = app.descendants(matching: .any).matching(identifier: "podcastDetail.favorite").firstMatch
		XCTAssertTrue(favoriteButton.waitForExistence(timeout: 5))
		XCTAssertEqual(favoriteButton.label, "Usuń z ulubionych")
		favoriteButton.tap()

		let predicate = NSPredicate(format: "label == %@", "Dodaj do ulubionych")
		let waitExpectation = expectation(for: predicate, evaluatedWith: favoriteButton)
		XCTAssertEqual(XCTWaiter().wait(for: [waitExpectation], timeout: 5), .completed)

		openFavoritesFromMenu(in: app)

		let favoritesPodcastRow = app.descendants(matching: .any).matching(identifier: "podcast.row.1").firstMatch
		XCTAssertFalse(favoritesPodcastRow.waitForExistence(timeout: 2))
		tapBackButton(in: app)
	}

	func testPodcastDetailShowsCommentsAndCanOpenThem() {
		let app = makeApp()
		app.launch()

		app.tabBars.buttons["Nowości"].tap()

		let podcastRow = app.descendants(matching: .any).matching(identifier: "podcast.row.1").firstMatch
		XCTAssertTrue(podcastRow.waitForExistence(timeout: 5))
		podcastRow.tap()

		let commentsSummary = app.descendants(matching: .any).matching(identifier: "podcastDetail.commentsSummary").firstMatch
		XCTAssertTrue(commentsSummary.waitForExistence(timeout: 5))

		let predicate = NSPredicate(format: "label == %@", "2 komentarze")
		let waitExpectation = expectation(for: predicate, evaluatedWith: commentsSummary)
		XCTAssertEqual(XCTWaiter().wait(for: [waitExpectation], timeout: 5), .completed)

		commentsSummary.tap()

		let commentsList = app.descendants(matching: .any).matching(identifier: "comments.list").firstMatch
		XCTAssertTrue(commentsList.waitForExistence(timeout: 5))

		let commentRow = app.descendants(matching: .any).matching(identifier: "comment.row.1001").firstMatch
		XCTAssertTrue(commentRow.waitForExistence(timeout: 5))
		commentRow.tap()

		let commentContent = app.descendants(matching: .any).matching(identifier: "comment.content").firstMatch
		XCTAssertTrue(commentContent.waitForExistence(timeout: 5))
	}

	func testPodcastDetailActionsWorkWithLargeContent() {
		let app = makeApp(additionalLaunchArguments: ["UI_TESTING_LARGE_PODCAST_CONTENT"])
		app.launch()

		app.tabBars.buttons["Nowości"].tap()

		let podcastRow = app.descendants(matching: .any).matching(identifier: "podcast.row.1").firstMatch
		XCTAssertTrue(podcastRow.waitForExistence(timeout: 5))
		podcastRow.tap()

		let favoriteButton = app.descendants(matching: .any).matching(identifier: "podcastDetail.favorite").firstMatch
		XCTAssertTrue(favoriteButton.waitForExistence(timeout: 5))
		favoriteButton.tap()

		let favoritePredicate = NSPredicate(format: "label == %@", "Usuń z ulubionych")
		let favoriteWaitExpectation = expectation(for: favoritePredicate, evaluatedWith: favoriteButton)
		XCTAssertEqual(XCTWaiter().wait(for: [favoriteWaitExpectation], timeout: 5), .completed)

		let commentsSummary = app.descendants(matching: .any).matching(identifier: "podcastDetail.commentsSummary").firstMatch
		XCTAssertTrue(commentsSummary.waitForExistence(timeout: 5))

		let commentsPredicate = NSPredicate(format: "label == %@", "2 komentarze")
		let commentsWaitExpectation = expectation(for: commentsPredicate, evaluatedWith: commentsSummary)
		XCTAssertEqual(XCTWaiter().wait(for: [commentsWaitExpectation], timeout: 5), .completed)
	}

	func testFavoriteTopicPlayActionOpensPlayer() {
		let app = makeApp()
		app.launch()

		app.tabBars.buttons["Nowości"].tap()

		let podcastRow = app.descendants(matching: .any).matching(identifier: "podcast.row.1").firstMatch
		XCTAssertTrue(podcastRow.waitForExistence(timeout: 5))
		podcastRow.tap()

		let listenButton = app.descendants(matching: .any).matching(identifier: "podcastDetail.listen").firstMatch
		XCTAssertTrue(listenButton.waitForExistence(timeout: 5))
		listenButton.tap()

		let markersButton = app.descendants(matching: .any).matching(identifier: "player.showChapterMarkers").firstMatch
		XCTAssertTrue(markersButton.waitForExistence(timeout: 5))
		markersButton.tap()

		let introMarker = app.buttons["Intro"].firstMatch
		XCTAssertTrue(introMarker.waitForExistence(timeout: 5))
		introMarker.press(forDuration: 1.0)

		let addFavorite = app.buttons["Dodaj do ulubionych"].firstMatch
		XCTAssertTrue(addFavorite.waitForExistence(timeout: 5))
		addFavorite.tap()

		tapBackButton(in: app)
		tapBackButton(in: app)

		openFavoritesFromMenu(in: app)

		let filter = app.segmentedControls["favorites.filter"]
		XCTAssertTrue(filter.waitForExistence(timeout: 5))
		filter.buttons["Tematy"].tap()

		let topicRow = app.descendants(matching: .any).matching(identifier: "favorites.topic.1.0").firstMatch
		XCTAssertTrue(topicRow.waitForExistence(timeout: 5))
		topicRow.press(forDuration: 1.0)

		let playButton = app.buttons["Odtwarzaj od tego miejsca"].firstMatch
		let playMenuItem = app.menuItems["Odtwarzaj od tego miejsca"].firstMatch
		if playButton.waitForExistence(timeout: 2) {
			playButton.tap()
		} else {
			XCTAssertTrue(playMenuItem.waitForExistence(timeout: 2))
			playMenuItem.tap()
		}

		let playPauseButton = app.descendants(matching: .any).matching(identifier: "player.playPause").firstMatch
		XCTAssertTrue(playPauseButton.waitForExistence(timeout: 5))
	}

	func testCanAddArticleToFavoritesAndFilterIt() {
		let app = makeApp()
		app.launch()

		app.tabBars.buttons["Nowości"].tap()

		let articleRow = app.descendants(matching: .any).matching(identifier: "article.row.2").firstMatch
		XCTAssertTrue(articleRow.waitForExistence(timeout: 5))
		articleRow.tap()

		let content = app.descendants(matching: .any).matching(identifier: "articleDetail.content").firstMatch
		XCTAssertTrue(content.waitForExistence(timeout: 5))

		let shareButton = app.descendants(matching: .any).matching(identifier: "articleDetail.share").firstMatch
		XCTAssertTrue(shareButton.waitForExistence(timeout: 5))

		let favoriteButton = app.descendants(matching: .any).matching(identifier: "articleDetail.favorite").firstMatch
		XCTAssertTrue(favoriteButton.waitForExistence(timeout: 5))
		favoriteButton.tap()

		openFavoritesFromMenu(in: app)

		let filter = app.segmentedControls["favorites.filter"]
		XCTAssertTrue(filter.waitForExistence(timeout: 5))
		filter.buttons["Artykuły"].tap()

		let favoritesArticleRow = app.descendants(matching: .any).matching(identifier: "article.row.2").firstMatch
		XCTAssertTrue(favoritesArticleRow.waitForExistence(timeout: 5))
	}

	func testCanOpenPodcastCategoryAndSeeItems() {
		let app = makeApp()
		app.launch()

		app.tabBars.buttons["Podcasty"].tap()

		let categoryRow = app.descendants(matching: .any).matching(identifier: "category.row.10").firstMatch
		XCTAssertTrue(categoryRow.waitForExistence(timeout: 5))
		categoryRow.tap()

		let categoryList = app.descendants(matching: .any).matching(identifier: "categoryPodcasts.list").firstMatch
		XCTAssertTrue(categoryList.waitForExistence(timeout: 5))

		let podcastRow = app.descendants(matching: .any).matching(identifier: "podcast.row.1").firstMatch
		XCTAssertTrue(podcastRow.waitForExistence(timeout: 5))
		podcastRow.tap()

		let content = app.descendants(matching: .any).matching(identifier: "podcastDetail.content").firstMatch
		XCTAssertTrue(content.waitForExistence(timeout: 5))
	}

	func testCanOpenArticleCategoryAndSeeItems() {
		let app = makeApp()
		app.launch()

		app.tabBars.buttons["Artykuły"].tap()

		let categoryRow = app.descendants(matching: .any).matching(identifier: "category.row.20").firstMatch
		XCTAssertTrue(categoryRow.waitForExistence(timeout: 5))
		categoryRow.tap()

		let categoryList = app.descendants(matching: .any).matching(identifier: "categoryArticles.list").firstMatch
		XCTAssertTrue(categoryList.waitForExistence(timeout: 5))

		let articleRow = app.descendants(matching: .any).matching(identifier: "podcast.row.2").firstMatch
		XCTAssertTrue(articleRow.waitForExistence(timeout: 5))
		articleRow.tap()

		let content = app.descendants(matching: .any).matching(identifier: "articleDetail.content").firstMatch
		XCTAssertTrue(content.waitForExistence(timeout: 5))
	}

	func testCanSearchAndOpenPodcastFromResults() {
		let app = makeApp()
		app.launch()

		app.tabBars.buttons["Szukaj"].tap()

		let searchField = app.descendants(matching: .any).matching(identifier: "search.field").firstMatch
		XCTAssertTrue(searchField.waitForExistence(timeout: 5))
		searchField.tap()
		searchField.typeText("test")

		let searchButton = app.descendants(matching: .any).matching(identifier: "search.button").firstMatch
		XCTAssertTrue(searchButton.exists)
		searchButton.tap()

		let podcastRow = app.descendants(matching: .any).matching(identifier: "podcast.row.1").firstMatch
		XCTAssertTrue(podcastRow.waitForExistence(timeout: 5))
		XCTAssertEqual(podcastRow.label, "Podcast. Test podcast")
		podcastRow.tap()

		let content = app.descendants(matching: .any).matching(identifier: "podcastDetail.content").firstMatch
		XCTAssertTrue(content.waitForExistence(timeout: 5))
	}

	func testContentKindLabelPositionUpdatesImmediately() {
		let app = makeApp()
		app.launch()

		app.tabBars.buttons["Nowości"].tap()

		let initialRow = app.descendants(matching: .any).matching(identifier: "podcast.row.1").firstMatch
		XCTAssertTrue(initialRow.waitForExistence(timeout: 5))
		XCTAssertEqual(initialRow.label, "Podcast. Test podcast")

		openSettingsFromMenu(in: app)

		let picker = app.segmentedControls["settings.contentKindLabelPosition"]
		XCTAssertTrue(picker.waitForExistence(timeout: 5))
		picker.buttons["Po"].tap()
		let pickerAfterTap = app.segmentedControls["settings.contentKindLabelPosition"]
		XCTAssertTrue(pickerAfterTap.waitForExistence(timeout: 5))
		XCTAssertEqual(pickerAfterTap.value as? String, "Po")

		tapBackButton(in: app)

		let updatedRow = app.descendants(matching: .any).matching(identifier: "podcast.row.1").firstMatch
		XCTAssertTrue(updatedRow.waitForExistence(timeout: 5))

		let expectedLabel = "Test podcast. Podcast"
		let predicate = NSPredicate(format: "label == %@", expectedLabel)
		let waitExpectation = expectation(for: predicate, evaluatedWith: updatedRow)
		let result = XCTWaiter().wait(for: [waitExpectation], timeout: 5)
		if result != .completed {
			XCTFail("Expected label '\(expectedLabel)', got '\(updatedRow.label)'.")
		}
	}

	func testCanSearchArticlesWhenScopeIsArticles() {
		let app = makeApp()
		app.launch()

		app.tabBars.buttons["Szukaj"].tap()

		let scopePicker = app.segmentedControls["search.scope"]
		XCTAssertTrue(scopePicker.waitForExistence(timeout: 5))
		scopePicker.buttons["Artykuły"].tap()

		let searchField = app.descendants(matching: .any).matching(identifier: "search.field").firstMatch
		XCTAssertTrue(searchField.waitForExistence(timeout: 5))
		searchField.tap()
		searchField.typeText("test")

		let searchButton = app.descendants(matching: .any).matching(identifier: "search.button").firstMatch
		XCTAssertTrue(searchButton.exists)
		searchButton.tap()

		let articleRow = app.descendants(matching: .any).matching(identifier: "article.row.2").firstMatch
		XCTAssertTrue(articleRow.waitForExistence(timeout: 5))
		XCTAssertEqual(articleRow.label, "Artykuł. Test artykuł")
		articleRow.tap()

		let content = app.descendants(matching: .any).matching(identifier: "articleDetail.content").firstMatch
		XCTAssertTrue(content.waitForExistence(timeout: 5))
	}

	func testCanOpenArticleFromNewsAndSeeReadableContent() {
		let app = makeApp()
		app.launch()

		app.tabBars.buttons["Nowości"].tap()

		let articleRow = app.descendants(matching: .any).matching(identifier: "article.row.2").firstMatch
		XCTAssertTrue(articleRow.waitForExistence(timeout: 5))
		articleRow.tap()

		let content = app.descendants(matching: .any).matching(identifier: "articleDetail.content").firstMatch
		XCTAssertTrue(content.waitForExistence(timeout: 5))
	}

	func testRadioContactShowsNoLiveAlert() {
		let app = makeApp()
		app.launch()

		app.tabBars.buttons["Tyfloradio"].tap()

		let radioButton = app.descendants(matching: .any).matching(identifier: "more.tyfloradio").firstMatch
		XCTAssertTrue(radioButton.waitForExistence(timeout: 5))
		radioButton.tap()

		let contactButton = app.descendants(matching: .any).matching(identifier: "player.contactRadio").firstMatch
		XCTAssertTrue(contactButton.waitForExistence(timeout: 5))
		contactButton.tap()

		let alert = app.alerts["Błąd"]
		XCTAssertTrue(alert.waitForExistence(timeout: 5))
		XCTAssertTrue(alert.staticTexts["Na antenie Tyfloradia nie trwa teraz żadna audycja interaktywna."].exists)
	}

	func testCanOpenContactFormAndSendMessageWhenAvailable() {
		let app = makeApp(additionalLaunchArguments: ["UI_TESTING_TP_AVAILABLE"])
		app.launch()

		app.tabBars.buttons["Tyfloradio"].tap()

		let radioButton = app.descendants(matching: .any).matching(identifier: "more.tyfloradio").firstMatch
		XCTAssertTrue(radioButton.waitForExistence(timeout: 5))
		radioButton.tap()

		let contactButton = app.descendants(matching: .any).matching(identifier: "player.contactRadio").firstMatch
		XCTAssertTrue(contactButton.waitForExistence(timeout: 5))
		contactButton.tap()

		let textMenuItem = app.descendants(matching: .any).matching(identifier: "contact.menu.text").firstMatch
		XCTAssertTrue(textMenuItem.waitForExistence(timeout: 5))
		textMenuItem.tap()

		let nameField = app.descendants(matching: .any).matching(identifier: "contact.name").firstMatch
		XCTAssertTrue(nameField.waitForExistence(timeout: 5))
		nameField.tap()
		nameField.typeText("UI Test")

		let messageField = app.descendants(matching: .any).matching(identifier: "contact.message").firstMatch
		XCTAssertTrue(messageField.exists)
		messageField.tap()
		messageField.typeText("\nWiadomość testowa")

		let sendButton = app.descendants(matching: .any).matching(identifier: "contact.send").firstMatch
		XCTAssertTrue(sendButton.exists)
		sendButton.tap()

		let playPauseButton = app.descendants(matching: .any).matching(identifier: "player.playPause").firstMatch
		if !playPauseButton.waitForExistence(timeout: 1) {
			tapBackButton(in: app)
		}
		if !playPauseButton.waitForExistence(timeout: 1) {
			tapBackButton(in: app)
		}
		XCTAssertTrue(playPauseButton.waitForExistence(timeout: 5))
	}

	func testPullToRefreshUpdatesLists() {
		let app = makeApp()
		app.launch()

		let newsList = app.descendants(matching: .any).matching(identifier: "news.list").firstMatch
		XCTAssertTrue(newsList.waitForExistence(timeout: 5))
		let initialNewsRow = app.descendants(matching: .any).matching(identifier: "podcast.row.1").firstMatch
		XCTAssertTrue(initialNewsRow.waitForExistence(timeout: 5))
		XCTAssertEqual(initialNewsRow.label, "Podcast. Test podcast")

		let initialArticleRow = app.descendants(matching: .any).matching(identifier: "article.row.2").firstMatch
		XCTAssertTrue(initialArticleRow.waitForExistence(timeout: 5))
		XCTAssertEqual(initialArticleRow.label, "Artykuł. Test artykuł")

		app.tabBars.buttons["Podcasty"].tap()
		let podcastCategoriesList = app.descendants(matching: .any).matching(identifier: "podcastCategories.list").firstMatch
		XCTAssertTrue(podcastCategoriesList.waitForExistence(timeout: 5))
		let initialPodcastCategory = app.descendants(matching: .any).matching(identifier: "category.row.10").firstMatch
		XCTAssertTrue(initialPodcastCategory.waitForExistence(timeout: 5))
		let refreshedPodcastCategory = app.descendants(matching: .any).matching(identifier: "category.row.11").firstMatch
		pullToRefresh(podcastCategoriesList, untilExists: refreshedPodcastCategory)
		XCTAssertEqual(refreshedPodcastCategory.label, "Test podcasty 2")

		let podcastCategoryRow = app.descendants(matching: .any).matching(identifier: "category.row.10").firstMatch
		XCTAssertTrue(podcastCategoryRow.waitForExistence(timeout: 5))
		podcastCategoryRow.tap()

		let categoryPodcastsList = app.descendants(matching: .any).matching(identifier: "categoryPodcasts.list").firstMatch
		XCTAssertTrue(categoryPodcastsList.waitForExistence(timeout: 5))
		let initialCategoryPodcast = app.descendants(matching: .any).matching(identifier: "podcast.row.1").firstMatch
		XCTAssertTrue(initialCategoryPodcast.waitForExistence(timeout: 5))
		let refreshedCategoryPodcast = app.descendants(matching: .any).matching(identifier: "podcast.row.4").firstMatch
		pullToRefresh(categoryPodcastsList, untilExists: refreshedCategoryPodcast)
		XCTAssertEqual(refreshedCategoryPodcast.label, "Test podcast w kategorii 2")

		app.tabBars.buttons["Artykuły"].tap()
		let articleCategoriesList = app.descendants(matching: .any).matching(identifier: "articleCategories.list").firstMatch
		XCTAssertTrue(articleCategoriesList.waitForExistence(timeout: 5))
		let initialArticleCategory = app.descendants(matching: .any).matching(identifier: "category.row.20").firstMatch
		XCTAssertTrue(initialArticleCategory.waitForExistence(timeout: 5))
		let refreshedArticleCategory = app.descendants(matching: .any).matching(identifier: "category.row.21").firstMatch
		pullToRefresh(articleCategoriesList, untilExists: refreshedArticleCategory)
		XCTAssertEqual(refreshedArticleCategory.label, "Test artykuły 2")

		let articleCategoryRow = app.descendants(matching: .any).matching(identifier: "category.row.20").firstMatch
		XCTAssertTrue(articleCategoryRow.waitForExistence(timeout: 5))
		articleCategoryRow.tap()

		let categoryArticlesList = app.descendants(matching: .any).matching(identifier: "categoryArticles.list").firstMatch
		XCTAssertTrue(categoryArticlesList.waitForExistence(timeout: 5))
		let initialCategoryArticle = app.descendants(matching: .any).matching(identifier: "podcast.row.2").firstMatch
		XCTAssertTrue(initialCategoryArticle.waitForExistence(timeout: 5))
		let refreshedCategoryArticle = app.descendants(matching: .any).matching(identifier: "podcast.row.5").firstMatch
		pullToRefresh(categoryArticlesList, untilExists: refreshedCategoryArticle)
		XCTAssertEqual(refreshedCategoryArticle.label, "Test artykuł 2")
	}

	func testListsRecoverAutomaticallyWhenFirstRequestFails() {
		let app = makeApp(additionalLaunchArguments: ["UI_TESTING_FAIL_FIRST_REQUEST"])
		app.launch()

		let newsList = app.descendants(matching: .any).matching(identifier: "news.list").firstMatch
		XCTAssertTrue(newsList.waitForExistence(timeout: 5))
		let firstNewsRow = app.descendants(matching: .any).matching(identifier: "podcast.row.1").firstMatch
		XCTAssertTrue(firstNewsRow.waitForExistence(timeout: 10))

		app.tabBars.buttons["Podcasty"].tap()
		let categoryRow = app.descendants(matching: .any).matching(identifier: "category.row.10").firstMatch
		XCTAssertTrue(categoryRow.waitForExistence(timeout: 10))
		categoryRow.tap()
		let firstCategoryPodcast = app.descendants(matching: .any).matching(identifier: "podcast.row.1").firstMatch
		XCTAssertTrue(firstCategoryPodcast.waitForExistence(timeout: 10))

		app.tabBars.buttons["Artykuły"].tap()
		let articleCategory = app.descendants(matching: .any).matching(identifier: "category.row.20").firstMatch
		XCTAssertTrue(articleCategory.waitForExistence(timeout: 10))
	}

	func testSearchRecoversAutomaticallyWhenFirstRequestFails() {
		let app = makeApp(additionalLaunchArguments: ["UI_TESTING_FAIL_FIRST_REQUEST"])
		app.launch()

		app.tabBars.buttons["Szukaj"].tap()

		let searchList = app.descendants(matching: .any).matching(identifier: "search.list").firstMatch
		XCTAssertTrue(searchList.waitForExistence(timeout: 5))

		let searchField = app.descendants(matching: .any).matching(identifier: "search.field").firstMatch
		XCTAssertTrue(searchField.waitForExistence(timeout: 5))
		searchField.tap()
		searchField.typeText("test")

		let searchButton = app.descendants(matching: .any).matching(identifier: "search.button").firstMatch
		XCTAssertTrue(searchButton.exists)
		searchButton.tap()

		let firstResult = app.descendants(matching: .any).matching(identifier: "podcast.row.1").firstMatch
		XCTAssertTrue(firstResult.waitForExistence(timeout: 10))
	}

	func testCanBrowsePodcastCategoriesAndOpenPodcast() {
		let app = makeApp()
		app.launch()

		app.tabBars.buttons["Podcasty"].tap()

		let categoryRow = app.descendants(matching: .any).matching(identifier: "category.row.10").firstMatch
		XCTAssertTrue(categoryRow.waitForExistence(timeout: 5))
		XCTAssertEqual(categoryRow.label, "Test podcasty")
		categoryRow.tap()

		let podcastRow = app.descendants(matching: .any).matching(identifier: "podcast.row.1").firstMatch
		XCTAssertTrue(podcastRow.waitForExistence(timeout: 5))
		podcastRow.tap()

		let content = app.descendants(matching: .any).matching(identifier: "podcastDetail.content").firstMatch
		XCTAssertTrue(content.waitForExistence(timeout: 5))
	}

	func testCanBrowseArticleCategoriesAndOpenArticle() {
		let app = makeApp()
		app.launch()

		app.tabBars.buttons["Artykuły"].tap()

		let categoryRow = app.descendants(matching: .any).matching(identifier: "category.row.20").firstMatch
		XCTAssertTrue(categoryRow.waitForExistence(timeout: 5))
		XCTAssertEqual(categoryRow.label, "Test artykuły")
		categoryRow.tap()

		let articleRow = app.descendants(matching: .any).matching(identifier: "podcast.row.2").firstMatch
		XCTAssertTrue(articleRow.waitForExistence(timeout: 5))
		articleRow.tap()

		let content = app.descendants(matching: .any).matching(identifier: "articleDetail.content").firstMatch
		XCTAssertTrue(content.waitForExistence(timeout: 5))
	}

	func testCanBrowseMagazineAndOpenArticle() {
		let app = makeApp()
		app.launch()

		app.tabBars.buttons["Artykuły"].tap()

		let magazineRow = app.descendants(matching: .any).matching(identifier: "articleCategories.magazine").firstMatch
		XCTAssertTrue(magazineRow.waitForExistence(timeout: 5))
		magazineRow.tap()

		let yearsList = app.descendants(matching: .any).matching(identifier: "magazine.years.list").firstMatch
		XCTAssertTrue(yearsList.waitForExistence(timeout: 5))

		let yearRow = app.descendants(matching: .any).matching(identifier: "magazine.year.2025").firstMatch
		XCTAssertTrue(yearRow.waitForExistence(timeout: 5))
		yearRow.tap()

		let issueRow = app.descendants(matching: .any).matching(identifier: "magazine.issue.7772").firstMatch
		XCTAssertTrue(issueRow.waitForExistence(timeout: 5))
		issueRow.tap()

		let issueNavigationBar = app.navigationBars["Tyfloświat 4/2025"]
		XCTAssertTrue(issueNavigationBar.waitForExistence(timeout: 5))
	}

	func testCanNavigateBackFromPodcastDetail() {
		let app = makeApp()
		app.launch()

		app.tabBars.buttons["Podcasty"].tap()

		let categoriesList = app.descendants(matching: .any).matching(identifier: "podcastCategories.list").firstMatch
		XCTAssertTrue(categoriesList.waitForExistence(timeout: 5))

		let categoryRow = app.descendants(matching: .any).matching(identifier: "category.row.10").firstMatch
		XCTAssertTrue(categoryRow.waitForExistence(timeout: 5))
		categoryRow.tap()

		let categoryPodcastsList = app.descendants(matching: .any).matching(identifier: "categoryPodcasts.list").firstMatch
		XCTAssertTrue(categoryPodcastsList.waitForExistence(timeout: 5))

		let podcastRow = app.descendants(matching: .any).matching(identifier: "podcast.row.1").firstMatch
		XCTAssertTrue(podcastRow.waitForExistence(timeout: 5))
		podcastRow.tap()

		let content = app.descendants(matching: .any).matching(identifier: "podcastDetail.content").firstMatch
		XCTAssertTrue(content.waitForExistence(timeout: 5))

		tapBackButton(in: app)
		XCTAssertTrue(categoryPodcastsList.waitForExistence(timeout: 5))

		tapBackButton(in: app)
		XCTAssertTrue(categoriesList.waitForExistence(timeout: 5))
	}

	func testCanNavigateBackFromArticleDetail() {
		let app = makeApp()
		app.launch()

		app.tabBars.buttons["Artykuły"].tap()

		let categoriesList = app.descendants(matching: .any).matching(identifier: "articleCategories.list").firstMatch
		XCTAssertTrue(categoriesList.waitForExistence(timeout: 5))

		let categoryRow = app.descendants(matching: .any).matching(identifier: "category.row.20").firstMatch
		XCTAssertTrue(categoryRow.waitForExistence(timeout: 5))
		categoryRow.tap()

		let categoryArticlesList = app.descendants(matching: .any).matching(identifier: "categoryArticles.list").firstMatch
		XCTAssertTrue(categoryArticlesList.waitForExistence(timeout: 5))

		let articleRow = app.descendants(matching: .any).matching(identifier: "podcast.row.2").firstMatch
		XCTAssertTrue(articleRow.waitForExistence(timeout: 5))
		articleRow.tap()

		let content = app.descendants(matching: .any).matching(identifier: "articleDetail.content").firstMatch
		XCTAssertTrue(content.waitForExistence(timeout: 5))

		tapBackButton(in: app)
		XCTAssertTrue(categoryArticlesList.waitForExistence(timeout: 5))

		tapBackButton(in: app)
		XCTAssertTrue(categoriesList.waitForExistence(timeout: 5))
	}
}
