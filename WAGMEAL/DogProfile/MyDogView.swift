import SwiftUI
import FirebaseAnalytics

struct MyDogView: View {
    @Binding var selectedDogID: String?
    @ObservedObject var dogVM: DogProfileViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var foodVM: DogFoodViewModel
    @StateObject private var evalVM: EvaluationViewModel

    @State private var isShowingDogManagement = false
    @State private var showLoginSheet = false
    @State private var selectedDogForDetail: DogProfile? = nil
    @State private var showDetail = false
    @State private var dogToDelete: DogProfile? = nil

    // 「いまのごはん」行タップ → 評価詳細へ
    @State private var selectedCurrentFood: DogFood? = nil
    @State private var selectedCurrentEvaluation: Evaluation? = nil
    @State private var showCurrentEvaluationDetail = false

    init(
        selectedDogID: Binding<String?>,
        dogVM: DogProfileViewModel,
        evalVM: EvaluationViewModel = EvaluationViewModel()
    ) {
        self._selectedDogID = selectedDogID
        self.dogVM = dogVM
        self._evalVM = StateObject(wrappedValue: evalVM)
    }

    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private var visibleDogs: [DogProfile] {
        dogVM.dogs.filter { $0.isDeleted != true }
    }

    // 単一のわんちゃんカード行を切り出してコンパイル負荷を下げる
    @ViewBuilder
    private func dogRow(for dog: DogProfile) -> some View {
        let foods = currentDogFoods(for: dog)

        DogCard(
            dog: dog,
            currentDogFoods: foods,
            onShowDetail: {
                if !isPreview {
                    Analytics.logEvent("dog_view", parameters: [
                        "dog_id": dog.id ?? "",
                        "from_screen": "my_dog"
                    ])
                }
                withAnimation(.spring()) {
                    selectedDogForDetail = dog
                    showDetail = true
                }
            },
            onTapCurrentFood: { food in
                // dogID + foodID から「いまのごはん」の最新評価を取得
                let eval = evalVM.currentFeedingLatestEvaluation(for: dog.id, dogFoodId: food.id)
                selectedCurrentFood = food
                selectedCurrentEvaluation = eval
                // eval が取れたときだけ遷移
                if eval != nil {
                    withAnimation(.spring()) {
                        showCurrentEvaluationDetail = true
                    }
                }
            }
        )
        .environmentObject(dogVM)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                dogToDelete = dog
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }
    
    private func currentDogFoods(for dog: DogProfile) -> [DogFood] {
        guard let dogID = dog.id else { return [] }

        // EvaluationViewModel側で集計済みの「いまのごはん」IDを参照
        let ids = evalVM.currentFeedingFoodIDs(for: dogID)
        guard !ids.isEmpty else { return [] }

            
        let foodsByID: [String: DogFood] = Dictionary(
            uniqueKeysWithValues: foodVM.dogFoods.compactMap { f in
                guard let id = f.id else { return nil }
                return (id, f)
            }
        )

        return ids.compactMap { foodsByID[$0] }
    }

    var body: some View {
        ZStack {
            // ===== 本体 =====
            VStack(spacing: 0) {
                List {
                    // 🐶 登録済みのわんちゃん一覧
                    ForEach(visibleDogs, id: \.id) { dog in
                        dogRow(for: dog)
                            .id("\(dog.id ?? "")_\(dog.imagePath ?? "no-image")")
                    }
                    Button {
                        if !isPreview {
                            Analytics.logEvent("dog_add_start", parameters: [
                                "from_screen": "my_dog"
                            ])
                        }
                        if authVM.isLoggedIn {
                            isShowingDogManagement = true
                        } else {
                            showLoginSheet = true
                        }
                    } label: {
                        Text(authVM.isLoggedIn ? "MyDog追加" : "ログインして\nMyDog追加")
                            .multilineTextAlignment(.center)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 14)
                            .background(
                                Color(red: 184/255, green: 164/255, blue: 144/255)
                                    .opacity(0.3)
                            )
                            .foregroundColor(
                                Color(red: 184/255, green: 164/255, blue: 144/255)
                            )
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden) // 念のためこの行のセパレーターも非表示
                }
                .listStyle(.plain)
                .listRowSeparator(.hidden)
                .refreshable {
                    if !isPreview {
                        Analytics.logEvent("mydog_refresh", parameters: nil)
                        dogVM.fetchDogs()
                    }
                    // Preview(モック)でも「いまのごはん」は更新したい
                    evalVM.listenCurrentFeedingFoodsForLoggedInUser()
                }
                .onAppear {
                    if !isPreview {
                        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                            AnalyticsParameterScreenName: "my_dog",
                            AnalyticsParameterScreenClass: "MyDogView"
                        ])
                        dogVM.fetchDogs()
                    }
                    // Preview(モック)でも「いまのごはん」を集計して表示できるようにする
                    evalVM.listenCurrentFeedingFoodsForLoggedInUser()
                }
            }
            .offset(x: showDetail ? -40 : 0) // 詳細表示中は少し左に押し出す
            .animation(.spring(), value: showDetail)
            .background(Color.white)

            // ===== 詳細画面をZStackで重ねる（RankingViewと同じパターン）=====
            if let dog = selectedDogForDetail, showDetail {
                ZStack {
                    // 背景を白で塗りつぶして、遷移時に下のカレンダーなどが透けて見えないようにする
                    Color.white
                        .ignoresSafeArea()

                    DogDetailView(
                        dog: dog,
                        onClose: {                      // ← ここで親の状態を落として戻る
                            withAnimation(.spring()) {
                                showDetail = false
                            }
                        }
                    )
                    .id(dog.id) // ← これが効きます
                    .onDisappear {
                        // 遷移が終わったタイミングで選択状態をクリア
                        selectedDogForDetail = nil
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                if value.translation.width > 100 {
                                    withAnimation(.spring()) {
                                        showDetail = false
                                    }
                                }
                            }
                    )
                }
                .zIndex(1)
                .animation(.spring(), value: showDetail)
            }

            // ===== 「いまのごはん」評価詳細（右からスライドイン）=====
            if showCurrentEvaluationDetail,
               let eval = selectedCurrentEvaluation,
               let food = selectedCurrentFood {
                ZStack {
                    Color.white
                        .ignoresSafeArea()

                    let item = EvaluationWithFood(evaluation: eval, dogFood: food)
                    EvaluationDetailView(item: item, isPresented: $showCurrentEvaluationDetail)
                        .onDisappear {
                            // 遷移が終わったタイミングで選択状態をクリア
                            selectedCurrentFood = nil
                            selectedCurrentEvaluation = nil
                        }
                        .gesture(
                            DragGesture()
                                .onEnded { value in
                                    if value.translation.width > 100 {
                                        withAnimation(.spring()) {
                                            showCurrentEvaluationDetail = false
                                        }
                                    }
                                }
                        )
                }
                .zIndex(2)
                .transition(.move(edge: .trailing))
            }
        }
        // DogManagementは従来どおりシートでOK（NavigationStack不要）
        .sheet(isPresented: $isShowingDogManagement) {
            NewDogView(selectedDogID: $selectedDogID, dogVM: dogVM)
        }
        .sheet(isPresented: $showLoginSheet) {
            LoginView()
                .environmentObject(authVM)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .alert(
            "本当に削除しますか？",
            isPresented: Binding(
                get: { dogToDelete != nil },
                set: { newValue in
                    if !newValue { dogToDelete = nil }
                }
            ),
            presenting: dogToDelete
        ) { dog in
            Button("キャンセル", role: .cancel) {
                dogToDelete = nil
            }
            Button("削除", role: .destructive) {
                if let dog = dogToDelete {
                    if !isPreview {
                        Analytics.logEvent("dog_profile_delete", parameters: [
                            "dog_id": dog.id ?? "",
                            "from_screen": "my_dog"
                        ])
                        dogVM.softDelete(dog: dog)
                    }
                }
                dogToDelete = nil
            }
        } message: { _ in
            Text("評価データは残ります")
        }
        .onChange(of: authVM.isLoggedIn) { isLoggedIn in
            if isLoggedIn {
                showLoginSheet = false
            }
        }
        .edgesIgnoringSafeArea(.bottom)
        .background(Color.white)
    }
}

// MARK: - Previews

#Preview("MyDogView – Logged Out") {
    struct MyDogPreviewWrapper: View {
        @State private var selectedDogID: String? = nil
        var body: some View {
            // ログアウト状態は犬データも空にして、追加導線を確認しやすくする
            let mockDogVM = DogProfileViewModel(mockDogs: [])

            let mockAuthVM = AuthViewModel()
            mockAuthVM.isLoggedIn = false
            mockAuthVM.username = nil

            return MyDogView(
                selectedDogID: $selectedDogID,
                dogVM: mockDogVM,
                evalVM: EvaluationViewModel(useMockData: true)
            )
            .environmentObject(mockAuthVM)
            .environmentObject(DogFoodViewModel(mockData: true))
            .background(Color(.systemGroupedBackground))
        }
    }
    return MyDogPreviewWrapper()
}

#Preview("MyDogView – Logged In") {
    struct MyDogPreviewWrapper: View {
        @State private var selectedDogID: String? = PreviewMockData.dogs.first?.id
        var body: some View {
            let mockDogVM = DogProfileViewModel(mockDogs: PreviewMockData.dogs)

            let mockAuthVM = AuthViewModel()
            mockAuthVM.isLoggedIn = true
            mockAuthVM.username = "たくみ"

            return MyDogView(
                selectedDogID: $selectedDogID,
                dogVM: mockDogVM,
                evalVM: EvaluationViewModel(useMockData: true)
            )
            .environmentObject(mockAuthVM)
            .environmentObject(DogFoodViewModel(mockData: true))
            .background(Color(.systemGroupedBackground))
        }
    }
    return MyDogPreviewWrapper()
}
