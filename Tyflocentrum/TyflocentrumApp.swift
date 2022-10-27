//
//  TyflocentrumApp.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 02/10/2022.
//

import SwiftUI

@main
struct TyflocentrumApp: App {
	@StateObject private var dataController = DataController()
    var body: some Scene {
        WindowGroup {
			ContentView().environment(\.managedObjectContext, dataController.container.viewContext)
        }
    }
}
