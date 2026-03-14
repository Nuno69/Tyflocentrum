//
//  DataController.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 12/10/2022.
//
import CoreData
import Foundation

final class DataController: ObservableObject {
	let container: NSPersistentContainer

	init(inMemory: Bool = false) {
		container = NSPersistentContainer(name: "Tyflocentrum")

		if inMemory {
			let description = NSPersistentStoreDescription()
			description.type = NSInMemoryStoreType
			container.persistentStoreDescriptions = [description]
		}

		container.loadPersistentStores { [weak self] _, error in
			guard let self else { return }
			guard let error else { return }

			AppLog.persistence.error(
				"Core Data store failed to load; falling back to in-memory store. Error: \(error.localizedDescription, privacy: .public)"
			)

			let description = NSPersistentStoreDescription()
			description.type = NSInMemoryStoreType
			self.container.persistentStoreDescriptions = [description]
			self.container.loadPersistentStores { _, error in
				if let error {
					AppLog.persistence.error(
						"In-memory Core Data store failed to load. Error: \(error.localizedDescription, privacy: .public)"
					)
				}
			}
		}
	}
}
