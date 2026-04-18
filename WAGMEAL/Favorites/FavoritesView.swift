import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseAnalytics

struct FavoritesView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var foodVM: DogFoodViewModel
    @EnvironmentObject var dogVM: DogProfileViewModel

    @Namespace private var namespace
    @State private var selectedDogFood: DogFood? = nil
    @State private var selectedMatchedID: String? = nil
    @State private var showDetail = false
    @State private var failedFoodImagePaths: Set<String> = []
    @State private var imageReloadKey = UUID()
    @State private var evaluationCountReloadKey = UUID()
    @State private var showLoginSheet = false
    @State private var loginSheetDetent: PresentationDetent = .large

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    // favoriteDogFoods 自体は Equatable ではないので、ID 配列（Equatable）で変更検知する
    private var favoriteFoodIDs: [String] {
        foodVM.favoriteDogFoods.compactMap { $0.id }.filter { !$0.isEmpty }
    }

    var body: some View {
        Group {
            if authVM.isLoggedIn {
                loggedInContent
            } else {
                loggedOutContent
            }
        }
        .sheet(isPresented: $showLoginSheet) {
            LoginView()
                .environmentObject(authVM)
                .presentationDetents([.large], selection: $loginSheetDetent)
                .presentationDragIndicator(.visible)
        }
        .onChange(of: authVM.isLoggedIn) { isLoggedIn in
            if isLoggedIn {
                showLoginSheet = false
            }
        }
    }

    private var loggedOutContent: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 24)

            Text("ログインしてお気に入りを登録")
                .font(.headline)

            Button {
                loginSheetDetent = .large
                showLoginSheet = true
            } label: {
                Text("ログイン")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(red: 184/255, green: 164/255, blue: 144/255))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private var loggedInContent: some View {
        ZStack {
            VStack(spacing: 0) {
                Text("お気に入り一覧")
                    .font(.title2).bold()
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal)

                Group {
                    if foodVM.favoriteDogFoods.isEmpty {
                        if foodVM.isLoading {
                            ProgressView("読み込み中...")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            Text("お気に入りがまだありません")
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    } else {
                        ScrollView {
                            let items = foodVM.favoriteDogFoods

                            LazyVGrid(columns: columns, spacing: 10) {
                                // ★ indices で回すとコンパイラが楽
                                ForEach(items.indices, id: \.self) { idx in
                                    let dogFood = items[idx]
                                    let matchedID = dogFood.id ?? dogFood.imagePath  // 安定ID

                                    dogFoodCard(dogFood, matchedID: matchedID) {
                                        withAnimation(.spring()) {
                                            Analytics.logEvent("food_view", parameters: [
                                                "food_id": dogFood.id ?? "",
                                                "from_screen": "favorites"
                                            ])
                                            selectedDogFood = dogFood
                                            selectedMatchedID = matchedID
                                            showDetail = true
                                        }
                                    }
                                }
                            }
                        }
                        .refreshable {
                            await refreshFavoritesLight()
                        }
                    }
                }

                if foodVM.isLoading && !foodVM.favoriteDogFoods.isEmpty {
                    ProgressView()
                        .scaleEffect(0.9)
                        .padding(.bottom, 8)
                }
            }
            .background(Color(.systemBackground))
            .allowsHitTesting(!showDetail)

            // 上層：詳細オーバーレイ
            if let dogFood = selectedDogFood, showDetail {
                DogFoodDetailView(
                    dogFood: dogFood,
                    dogs: dogVM.dogs,
                    namespace: namespace,
                    matchedID: selectedMatchedID ?? (dogFood.id ?? dogFood.imagePath),
                    isPresented: $showDetail
                )
                .environmentObject(foodVM)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .zIndex(1)
                .transition(.move(edge: .trailing))
                .gesture(
                    DragGesture().onEnded { value in
                        if value.translation.width > 100 {
                            withAnimation(.spring()) {
                                showDetail = false
                                selectedDogFood = nil
                                selectedMatchedID = nil
                            }
                        }
                    }
                )
            }
        }
        .onChange(of: favoriteFoodIDs) { ids in
            // お気に入り一覧に出ているIDだけ評価件数をリセットして取り直す
            guard !ids.isEmpty else { return }
            foodVM.resetEvaluationCountCache(only: ids)
            ids.forEach { id in
                foodVM.loadEvaluationCountIfNeeded(for: id)
            }
        }
        .onAppear {
            Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                AnalyticsParameterScreenName: "favorites",
                AnalyticsParameterScreenClass: "FavoritesView"
            ])
        }
    }

    private func dogFoodCard(_ dogFood: DogFood,
                             matchedID: String,
                             onTap: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            DogFoodImageView(
                imagePath: dogFood.imagePath,
                storagePath: dogFood.storagePath,
                matchedID: matchedID,
                namespace: namespace,
                enableMatchedGeometry: false,
                reloadKey: imageReloadKey,
                shouldRetry: failedFoodImagePaths.contains(dogFood.imagePath),
                onLoadResult: { success in
                    if success {
                        failedFoodImagePaths.remove(dogFood.imagePath)
                    } else {
                        failedFoodImagePaths.insert(dogFood.imagePath)
                    }
                }
            )

            if !dogFood.brandNonEmpty.isEmpty {
                Text(dogFood.brandNonEmpty)
                    .font(.caption2)
                    .foregroundColor(Color(red: 184/255, green: 164/255, blue: 144/255))
                    .lineLimit(1)
                    .padding(.leading, 10)
            }

            Text(dogFood.name)
                .font(.caption)
                .lineLimit(2)                          // 最大2行まで表示
                .multilineTextAlignment(.leading)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity,
                       minHeight: 32,                  // 1行でも2行分の高さを確保して段ズレ防止
                       alignment: .topLeading)
                .padding(.leading, 10)

            // ★ 評価件数 + お気に入り
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "ellipsis.message")

                    let cnt = foodVM.evaluationCount(for: dogFood.id)
                    Text(" \(cnt.map(String.init) ?? "—")")
                        .redacted(reason: cnt == nil ? .placeholder : [])
                }
                .font(.caption2)
                .foregroundColor(.secondary)

                Spacer()

                Button {
                    if let id = dogFood.id {
                        Analytics.logEvent("favorite_toggle", parameters: [
                            "food_id": id,
                            "is_favorite": !foodVM.isFavorite(dogFood.id),
                            "from_screen": "favorites"
                        ])
                        foodVM.toggleFavorite(dogFoodID: id)
                    }
                } label: {
                    Image(systemName: foodVM.isFavorite(dogFood.id) ? "heart.fill" : "heart")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 10)   // 星の左
            .padding(.trailing, 10)  // ハートの右

        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onAppear {
            // 各ドッグフードごとの評価件数キャッシュを必要に応じて取得
            foodVM.loadEvaluationCountIfNeeded(for: dogFood.id)
        }
        .task(id: evaluationCountReloadKey) {
            if let id = dogFood.id {
                foodVM.loadEvaluationCountIfNeeded(for: id)
            }
        }
    }

    @MainActor
    private func refreshFavoritesLight() async {
        imageReloadKey = UUID()

        let ids = favoriteFoodIDs
        guard !ids.isEmpty else { return }
        foodVM.resetEvaluationCountCache(only: ids)
        ids.forEach { id in
            foodVM.loadEvaluationCountIfNeeded(for: id)
        }
        evaluationCountReloadKey = UUID()
    }
}

// MARK: - Previews

struct FavoritesView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            FavoritesPreviewContainer(isLoggedIn: false)
                .previewDisplayName("Favorites / Logged Out")

            FavoritesPreviewContainer(isLoggedIn: true)
                .previewDisplayName("Favorites / Logged In")
        }
    }
}

private struct FavoritesPreviewContainer: View {
    @StateObject private var authVM: AuthViewModel
    @StateObject private var dogVM: DogProfileViewModel
    @StateObject private var foodVM: DogFoodViewModel

    init(isLoggedIn: Bool) {
        let a = AuthViewModel()
        a.isLoggedIn = isLoggedIn

        let d = DogProfileViewModel()
        d.dogs = PreviewMockData.dogs

        let f = DogFoodViewModel(mockData: true)

        _authVM = StateObject(wrappedValue: a)
        _dogVM = StateObject(wrappedValue: d)
        _foodVM = StateObject(wrappedValue: f)
    }

    var body: some View {
        FavoritesView()
            .environmentObject(authVM)
            .environmentObject(foodVM)
            .environmentObject(dogVM)
    }
}
