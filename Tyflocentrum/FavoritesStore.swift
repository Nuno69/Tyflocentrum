import Foundation

@MainActor
final class FavoritesStore: ObservableObject {
	private let storageKey: String
	private let userDefaults: UserDefaults

	@Published private(set) var items: [FavoriteItem] = []

	private var knownIDs = Set<String>()

	init(userDefaults: UserDefaults = .standard, storageKey: String = "favorites.v1") {
		self.userDefaults = userDefaults
		self.storageKey = storageKey

		let loaded = Self.load(from: userDefaults, key: storageKey)
		items = loaded
		knownIDs = Set(loaded.map(\.id))
	}

	func isFavorite(_ item: FavoriteItem) -> Bool {
		knownIDs.contains(item.id)
	}

	func toggle(_ item: FavoriteItem) {
		if isFavorite(item) {
			remove(item)
		} else {
			add(item)
		}
	}

	func add(_ item: FavoriteItem) {
		guard knownIDs.insert(item.id).inserted else { return }
		var updated = items
		updated.insert(item, at: 0)
		items = updated
		persist()
	}

	func remove(_ item: FavoriteItem) {
		remove(id: item.id)
	}

	func remove(id: String) {
		guard knownIDs.remove(id) != nil else { return }
		items = items.filter { $0.id != id }
		persist()
	}

	func filtered(_ filter: FavoritesFilter) -> [FavoriteItem] {
		guard let kind = filter.kind else { return items }
		return items.filter { $0.kind == kind }
	}

	private func persist() {
		let encoder = JSONEncoder()
		do {
			let data = try encoder.encode(items)
			userDefaults.set(data, forKey: storageKey)
		} catch {
			// Avoid crashing the app because of persistence issues.
		}
	}

	private static func load(from defaults: UserDefaults, key: String) -> [FavoriteItem] {
		guard let data = defaults.data(forKey: key) else { return [] }
		let decoder = JSONDecoder()
		return (try? decoder.decode([FavoriteItem].self, from: data)) ?? []
	}
}
