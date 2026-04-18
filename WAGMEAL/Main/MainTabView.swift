//
//  RootView.swift
//  Dogfood
//
//  Created by takumi kowatari on 2025/06/21.
//

import SwiftUI
import FirebaseAnalytics

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

    @StateObject private var rankingVM = RankingViewModel()
    @State private var searchReloadKey = UUID()
    @State private var myDogReloadKey = UUID()
    @State private var favoritesReloadKey = UUID()
    @State private var rankingReloadKey = UUID()

    // MARK: - Analytics
    private func logTabEvent(_ tab: MainTab, action: String) {
        Analytics.logEvent("tab_interaction", parameters: [
            "tab": String(describing: tab),
            "action": action
        ])
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                // 上部ヘッダー分の余白
                Spacer().frame(height: 60)

                // メインコンテンツ（各タブViewを生かしたまま表示切替して状態を保持）
                ZStack {
                    MyDogView(selectedDogID: $selectedDogID, dogVM: dogVM)
                        .id(myDogReloadKey)
                        .opacity(tabRouter.selectedTab == .myDog ? 1 : 0)
                        .allowsHitTesting(tabRouter.selectedTab == .myDog)

                    SearchView()
                        .id(searchReloadKey)
                        .opacity(tabRouter.selectedTab == .search ? 1 : 0)
                        .allowsHitTesting(tabRouter.selectedTab == .search)

                    FavoritesView()
                        .id(favoritesReloadKey)
                        .opacity(tabRouter.selectedTab == .favorites ? 1 : 0)
                        .allowsHitTesting(tabRouter.selectedTab == .favorites)

                    // TODO: データが十分に蓄積されたら RankingView() に戻す
                    // RankingView()
                    //     .id(rankingReloadKey)
                    //     .opacity(tabRouter.selectedTab == .ranking ? 1 : 0)
                    //     .allowsHitTesting(tabRouter.selectedTab == .ranking)
                    RankingComingSoonView()
                        .opacity(tabRouter.selectedTab == .ranking ? 1 : 0)
                        .allowsHitTesting(tabRouter.selectedTab == .ranking)
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
        .onChange(of: authVM.isLoggedIn) { isLoggedIn in
            if !isLoggedIn {
                // ログアウト時：前ユーザーの状態が残らないようにクリア
                selectedDogID = nil
                dogVM.dogs = []
                tabRouter.selectedTab = .myDog
                myDogReloadKey = UUID()
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    // MARK: - Tab Button

    private func tabButton(_ tab: MainTab, label: String, systemImage: String) -> some View {
        Button {
            if tabRouter.selectedTab == tab {
                logTabEvent(tab, action: "retap")
                // 🔁 同じタブをもう一度タップしたときの挙動
                switch tab {
                case .search:
                    Analytics.logEvent("tab_refresh", parameters: ["tab": "search"])
                    // 検索タブ再タップで「最初の検索画面」に戻すが、フィルターは維持する
                    viewModel.resetSearchUIStateKeepingFilters()
                    searchReloadKey = UUID()
                case .myDog:
                    Analytics.logEvent("tab_refresh", parameters: ["tab": "myDog"])
                    // MyDogタブ再タップで画面を再生成（詳細表示やシート状態をリセット）
                    myDogReloadKey = UUID()
                case .favorites:
                    Analytics.logEvent("tab_refresh", parameters: ["tab": "favorites"])
                    // お気に入りタブ再タップで最新状態にするため再生成
                    favoritesReloadKey = UUID()
                case .ranking:
                    Analytics.logEvent("tab_refresh", parameters: ["tab": "ranking"])
                    // ランキングタブ再タップで最新状態にするため再生成
                    rankingReloadKey = UUID()

                }
            } else {
                logTabEvent(tab, action: "switch")
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

// MARK: - ランキング準備中画面
private struct RankingComingSoonView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image("Logoline")
                .resizable()
                .scaledToFit()
                .frame(width: 100)
            Text("準備中")
                .font(.title2.bold())
            Text("ランキング機能は近日公開予定です")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
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
