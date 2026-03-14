import XCTest

@testable import Tyflocentrum

@MainActor
final class PagedFeedViewModelTests: XCTestCase {
	private struct StubItem: Identifiable, Decodable, Equatable {
		let id: Int
	}

	func testRefreshLoadsFirstPageAndCanLoadMoreWhenFullPageWithoutTotalPages() async {
		let viewModel = PagedFeedViewModel<StubItem>(perPage: 2)

		var requested: [(page: Int, perPage: Int)] = []
		let fetchPage: (Int, Int) async throws -> TyfloAPI.WPPage<StubItem> = { page, perPage in
			requested.append((page: page, perPage: perPage))
			return TyfloAPI.WPPage(
				items: [StubItem(id: 1), StubItem(id: 2)],
				total: nil,
				totalPages: nil
			)
		}

		await viewModel.refresh(fetchPage: fetchPage)

		XCTAssertEqual(requested.map(\.page), [1])
		XCTAssertEqual(requested.map(\.perPage), [2])
		XCTAssertEqual(viewModel.items.map(\.id), [1, 2])
		XCTAssertTrue(viewModel.hasLoaded)
		XCTAssertTrue(viewModel.canLoadMore)
		XCTAssertNil(viewModel.errorMessage)
	}

	func testLoadMoreAppendsNextPageAndStopsWhenLastPageIsPartial() async {
		let viewModel = PagedFeedViewModel<StubItem>(perPage: 2)

		let fetchPage: (Int, Int) async throws -> TyfloAPI.WPPage<StubItem> = { page, _ in
			switch page {
			case 1:
				return TyfloAPI.WPPage(items: [StubItem(id: 1), StubItem(id: 2)], total: nil, totalPages: 2)
			case 2:
				return TyfloAPI.WPPage(items: [StubItem(id: 3)], total: nil, totalPages: 2)
			default:
				return TyfloAPI.WPPage(items: [], total: nil, totalPages: 2)
			}
		}

		await viewModel.refresh(fetchPage: fetchPage)
		XCTAssertTrue(viewModel.canLoadMore)

		await viewModel.loadMore(fetchPage: fetchPage)
		XCTAssertEqual(viewModel.items.map(\.id), [1, 2, 3])
		XCTAssertFalse(viewModel.canLoadMore)
		XCTAssertNil(viewModel.loadMoreErrorMessage)
	}

	func testLoadMoreSetsErrorWhenPageAddsNoNewItemsButMorePagesRemain() async {
		let viewModel = PagedFeedViewModel<StubItem>(perPage: 2)

		let fetchPage: (Int, Int) async throws -> TyfloAPI.WPPage<StubItem> = { page, _ in
			switch page {
			case 1:
				return TyfloAPI.WPPage(items: [StubItem(id: 1), StubItem(id: 2)], total: nil, totalPages: 3)
			case 2:
				// Duplicate items -> insertedCount == 0, but more pages remain.
				return TyfloAPI.WPPage(items: [StubItem(id: 2), StubItem(id: 1)], total: nil, totalPages: 3)
			default:
				return TyfloAPI.WPPage(items: [], total: nil, totalPages: 3)
			}
		}

		await viewModel.refresh(fetchPage: fetchPage)
		XCTAssertTrue(viewModel.canLoadMore)

		await viewModel.loadMore(fetchPage: fetchPage)
		XCTAssertEqual(viewModel.items.map(\.id), [1, 2])
		XCTAssertTrue(viewModel.canLoadMore)
		XCTAssertEqual(viewModel.loadMoreErrorMessage, "Nie udało się pobrać kolejnych treści. Spróbuj ponownie.")
	}
}
