//
//  ContentView.swift
//  Dogfood
//
//  Created by takumi kowatari on 2025/06/20.
//
import SwiftUI
import FirebaseAnalytics

struct SearchView: View {
    @EnvironmentObject var viewModel: DogFoodViewModel   // ← これだけでOK！
    @EnvironmentObject var dogVM: DogProfileViewModel
    @State private var selectedDogIDs: Set<String> = []

    var body: some View {
        SearchResultsView(
            viewModel: viewModel,            // ← 同じインスタンスを渡せる
            selectedDogIDs: $selectedDogIDs,
            dogs: dogVM.dogs
        )
        .onAppear {
            Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                AnalyticsParameterScreenName: "search",
                AnalyticsParameterScreenClass: "SearchView"
            ])
        }
    }
}
