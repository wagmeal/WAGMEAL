//
//  ContentView.swift
//  Dogfood
//
//  Created by takumi kowatari on 2025/06/20.
//
import SwiftUI

struct SearchView: View {
    @EnvironmentObject var viewModel: DogFoodViewModel   // ← これだけでOK！
    @EnvironmentObject var dogVM: DogProfileViewModel
    @State private var selectedDogID: String? = nil

    var body: some View {
        SearchResultsView(
            viewModel: viewModel,            // ← 同じインスタンスを渡せる
            selectedDogID: $selectedDogID,
            dogs: dogVM.dogs
        )
    }
}

