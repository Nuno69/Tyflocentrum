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
    @StateObject private var api = TyfloAPI.shared
    @StateObject private var bass = BassHelper.shared
    var body: some Scene {
        WindowGroup {
            ContentView().environment(\.managedObjectContext, dataController.container.viewContext).environmentObject(api).environmentObject(bass)
        }
    }
}
