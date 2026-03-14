import SwiftUI

struct AppMenuContainer<Content: View>: View {
	let content: Content
	@State private var shouldShowFavorites = false
	@State private var shouldShowSettings = false

	var body: some View {
		content
			.toolbar {
				ToolbarItem(placement: .navigationBarLeading) {
					Menu {
						Button {
							shouldShowFavorites = true
						} label: {
							Label("Ulubione", systemImage: "star.fill")
						}
						.accessibilityIdentifier("app.menu.favorites")

						Button {
							shouldShowSettings = true
						} label: {
							Label("Ustawienia", systemImage: "gearshape.fill")
						}
						.accessibilityIdentifier("app.menu.settings")
					} label: {
						Label("Menu", systemImage: "line.3.horizontal")
							.labelStyle(.iconOnly)
					}
					.accessibilityHint("Otwiera menu aplikacji.")
					.accessibilityIdentifier("app.menu")
				}
			}
			.navigationDestination(isPresented: $shouldShowFavorites) {
				FavoritesView()
			}
			.navigationDestination(isPresented: $shouldShowSettings) {
				SettingsView()
			}
	}
}

extension View {
	func withAppMenu() -> some View {
		AppMenuContainer(content: self)
	}
}
