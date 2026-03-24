//
//  RootView.swift
//  Dogfood
//
//  Created by takumi kowatari on 2025/06/21.
//

import SwiftUI

enum MainTab: Int {
    case myDog
    case search
    case favorites
    case ranking
}

final class MainTabRouter: ObservableObject {
    @Published var selectedTab: MainTab = .myDog
}

struct MainTabView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var viewModel: DogFoodViewModel
    @EnvironmentObject var dogVM: DogProfileViewModel
    @EnvironmentObject var tabRouter: MainTabRouter   // ← 追加
    @AppStorage("selectedDogID") private var selectedDogID: String?

    @StateObject private var rankingVM = RankingViewModel(useMockData: false)
    @State private var searchReloadKey = UUID()

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                // 上部ヘッダー分の余白
                Spacer().frame(height: 60)

                // メインコンテンツ（選択中タブの画面を表示）
                ZStack {
                    switch tabRouter.selectedTab {
                    case .myDog:
                        MyDogView(selectedDogID: $selectedDogID, dogVM: dogVM)
                    case .search:
                        SearchView()
                            .id(searchReloadKey)
                    case .favorites:
                        FavoritesView()
                    case .ranking:
                        RankingView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // カスタムタブバー
                Divider()
                HStack(spacing: 0) {
                    tabButton(.myDog, label: "MyDog", systemImage: "dog")
                    tabButton(.search, label: "検索", systemImage: "magnifyingglass")
                    tabButton(.favorites, label: "お気に入り", systemImage: "heart")
                    tabButton(.ranking, label: "ランキング", systemImage: "crown")
                }
                .padding(.vertical, 6)
                .background(Color(.systemBackground))
            }

            MainHeaderView()
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    // MARK: - Tab Button

    private func tabButton(_ tab: MainTab, label: String, systemImage: String) -> some View {
        Button {
            if tabRouter.selectedTab == tab {
                // 🔁 同じタブをもう一度タップしたときの挙動
                if tab == .search {
                    // 検索タブ再タップで初期状態にリセット + 画面を再生成
                    viewModel.searchText = ""
                    viewModel.isSearchActive = false
                    searchReloadKey = UUID()
                }
            } else {
                // 違うタブを押したときは単純にタブを切り替え
                tabRouter.selectedTab = tab
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                Text(label)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(
                tabRouter.selectedTab == tab
                ? Color(red: 184/255, green: 164/255, blue: 144/255) // アクセントカラー
                : Color.secondary
            )
            .padding(.horizontal, 4)
        }
    }
}

#Preview {
    let authVM = AuthViewModel()
    let dogFoodVM = DogFoodViewModel()
    let dogProfileVM = DogProfileViewModel()
    let tabRouter = MainTabRouter()                 // ★ 追加

    MainTabView()
        .environmentObject(authVM)
        .environmentObject(dogFoodVM)
        .environmentObject(dogProfileVM)
        .environmentObject(tabRouter)              // ★ 追加
}
