//
//  DataController.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 12/10/2022.
//
import CoreData
import Foundation

class DataController: ObservableObject {
	let container = NSPersistentContainer(name: "Tyflocentrum")
	init() { // Tworzymy konstruktor
		container.loadPersistentStores { description, error in // Ładujemy nasze dane. Jako, że jesteśmy pesymistami to zakładamy, że coś pójdzie nie tak.
			if let error = error { // Jeżeli jest błąd, to...
				fatalError("Failed to load the data model!\n\(error.localizedDescription)") // Z takiego błędu nie można się wykaraskać. Jedyen co to możemy pokazać błąd.
			}
		}
	}
}
