//
//  ShortCategoryView.swift
//  Tyflocentrum
//
//  Created by Arkadiusz Świętnicki on 25/10/2022.
//
import Foundation
import SwiftUI
struct ShortCategoryView: View {
	let category: Category
	var body: some View {
		HStack {
			Text(category.name).font(.largeTitle)
			Text("\(category.count)").font(.subheadline)
		}.accessibilityElement(children: .combine)
	}
}
