import SwiftUI
import FirebaseFirestore
import FirebaseStorage
import FirebaseAnalytics


// MARK: - DogDetailView（タイル一覧＋並び替え）
struct DogDetailView: View {
    let dog: DogProfile
    let onClose: () -> Void
    @EnvironmentObject var tabRouter: MainTabRouter

    @State private var items: [EvaluationWithFood] = []
    @State private var isLoading = true
    @State private var minDelayPassed = false


    // 詳細遷移（ZStackオーバーレイ）
    @State private var selectedItem: EvaluationWithFood? = nil
    @State private var showEvalDetail = false
    // 表示切り替え（カレンダー / 一覧）
    enum ViewMode: Equatable { case calendar, list }
    @State private var viewMode: ViewMode = .calendar

    // Grid（SearchResultsViewと同じ3カラム）
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]


    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Text("\(dog.name)の記録（\(items.count)件）")
                    .font(.system(size: 20, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal)

                HeaderCountRow(
                    dog: dog,
                    count: items.count,
                    viewMode: $viewMode
                )
                .padding(.horizontal, 16)


                Group {
                    if isLoading || !minDelayPassed {
                        ProgressView("読み込み中…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .padding(.top, 8)
                    } else if items.isEmpty {
                        Text("まだ記録履歴がありません。")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .padding(.top, 8)
                    } else {
                        ZStack {
                            DogFoodCalendarView(items: items) { item in
                                withAnimation(.spring()) {
                                    Analytics.logEvent("evaluation_view", parameters: [
                                        "dog_id": dog.id ?? "",
                                        "evaluation_id": item.evaluation.id ?? "",
                                        "food_id": item.dogFood.id ?? "",
                                        "from": "dog_detail_calendar"
                                    ])
                                    selectedItem = item
                                    showEvalDetail = true
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .ignoresSafeArea(edges: .bottom)
                            .background(Color.white)
                            .opacity(viewMode == .calendar ? 1 : 0)
                            .allowsHitTesting(viewMode == .calendar)

                            DogEvaluationListView(
                                items: items,
                                onSelect: { item in
                                    withAnimation(.spring()) {
                                        Analytics.logEvent("evaluation_view", parameters: [
                                            "dog_id": dog.id ?? "",
                                            "evaluation_id": item.evaluation.id ?? "",
                                            "food_id": item.dogFood.id ?? "",
                                            "from": "dog_detail_list"
                                        ])
                                        selectedItem = item
                                        showEvalDetail = true
                                    }
                                }
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.white)
                            .opacity(viewMode == .list ? 1 : 0)
                            .allowsHitTesting(viewMode == .list)
                        }
                        .animation(.easeInOut(duration: 0.18), value: viewMode)
                    }
                }
            }
        .padding(.top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            // 左上の戻る
            Button {
                Analytics.logEvent("dog_detail_close", parameters: [
                    "dog_id": dog.id ?? ""
                ])
                onClose()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.blue)
                    .padding(10)
                    .background(Color.white.opacity(0.8), in: Circle())
            }
            .padding(.leading, 8)
            .padding(.top, 8)

            
            // 新しい評価詳細オーバーレイ
            if let item = selectedItem, showEvalDetail {
                EvaluationDetailView(item: item, isPresented: $showEvalDetail)
                    .zIndex(1)
                    .transition(.move(edge: .trailing))
                    .gesture(
                        DragGesture(minimumDistance: 10, coordinateSpace: .local)
                            .onEnded { value in
                                let shouldCloseByDistance = value.translation.width > 100
                                let shouldCloseByVelocity = value.predictedEndTranslation.width > 180
                                if shouldCloseByDistance || shouldCloseByVelocity {
                                    withAnimation(.spring()) { showEvalDetail = false }
                                }
                            }
                    )
            }

            // 右下の + ボタン（検索タブへ遷移）
            Button(action: {
                Analytics.logEvent("tab_interaction", parameters: [
                    "tab": "search",
                    "action": "switch",
                    "from_screen": "dog_detail"
                ])
                Analytics.logEvent("dog_add_from_detail", parameters: [
                    "dog_id": dog.id ?? ""
                ])
                withAnimation(.spring()) {
                    tabRouter.selectedTab = .search
                }
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color(red: 184/255, green: 164/255, blue: 144/255))
                    .clipShape(Circle())
                    .shadow(radius: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .onAppear {
            Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                AnalyticsParameterScreenName: "dog_detail",
                AnalyticsParameterScreenClass: "DogDetailView"
            ])
            Analytics.logEvent("dog_detail_view", parameters: [
                "dog_id": dog.id ?? "",
                "view_mode": (viewMode == .calendar) ? "calendar" : "list"
            ])
        }
        .onChange(of: showEvalDetail) { isPresented in
            // EvaluationDetailView が閉じられたタイミングで最新の情報を再取得
            if !isPresented {
                guard let dogID = dog.id else { return }
                resetStateForReload()
                startMinDelay()
                Task {
                    await fetchEvaluations(for: dogID)
                }
            }
        }
        .task(id: dog.id) {
            guard let dogID = dog.id else { return }
            resetStateForReload()
            startMinDelay()

            #if DEBUG
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                loadMock(); return
            }
            #endif
            await fetchEvaluations(for: dogID)
        }
        // (一覧シートは不要になったので削除)
    }


    // MARK: Firestore
    private func fetchEvaluations(for dogID: String) async {
        isLoading = true
        let db = Firestore.firestore()

        do {
            let snap = try await db.collection("evaluations")
                .whereField("dogID", isEqualTo: dogID)
                .getDocuments()

            let evaluations: [Evaluation] = snap.documents.compactMap { try? $0.data(as: Evaluation.self) }

            if evaluations.isEmpty {
                await MainActor.run {
                    withAnimation(.spring()) {
                        self.items = []
                        self.isLoading = false
                    }
                }
                return
            }

            var joined: [EvaluationWithFood] = []
            joined.reserveCapacity(evaluations.count)

            try await withThrowingTaskGroup(of: EvaluationWithFood?.self) { group in
                for ev in evaluations {
                    group.addTask {
                        do {
                            let doc = try await db.collection("dogfood").document(ev.dogFoodId).getDocument()
                            if let food = try? doc.data(as: DogFood.self) {
                                return EvaluationWithFood(evaluation: ev, dogFood: food)
                            } else {
                                print("⚠️ dogfood not found: \(ev.dogFoodId)")
                                return nil
                            }
                        } catch {
                            print("⚠️ dogfood fetch error (\(ev.dogFoodId)): \(error)")
                            return nil
                        }
                    }
                }
                for try await row in group { if let r = row { joined.append(r) } }
            }

            joined.sort { $0.evaluation.timestamp < $1.evaluation.timestamp }

            await MainActor.run {
                withAnimation(.spring()) {
                    self.items = joined
                    self.isLoading = false
                }
            }
        } catch {
            print("❌ Firestore取得エラー: \(error)")
            await MainActor.run {
                self.items = []
                self.isLoading = false
            }
        }
    }

    // ✅ 犬切替時の完全リセット
    private func resetStateForReload() {
        selectedItem = nil
        showEvalDetail = false
        items.removeAll()
        isLoading = true
    }

    private func startMinDelay() {
        minDelayPassed = false
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            minDelayPassed = true
        }
    }

    // MARK: Preview用
    private func loadMock() {
        let targetDogID = dog.id ?? PreviewMockData.dogs.first?.id ?? "dog_preview"
        let evs: [EvaluationWithFood] = PreviewMockData.evaluations
            .filter { $0.dogID == targetDogID }
            .compactMap { mock -> EvaluationWithFood? in
                guard let food = PreviewMockData.dogFood.first(where: { $0.id == mock.dogFoodId }) else { return nil }
                let eating = mock.ratings["eating"] ?? 0
                let condition = mock.ratings["condition"] ?? 0
                let costPerformance = mock.ratings["costPerformance"] ?? 0
                let storageEase = mock.ratings["storageEase"] ?? 0
                let repurchase = mock.ratings["repurchase"] ?? 0
                let eval = Evaluation(
                    id: UUID().uuidString,
                    dogID: mock.dogID,
                    dogName: mock.dogName,
                    breed: mock.breed,
                    sizeCategory: mock.sizeCategory,
                    dogFoodId: mock.dogFoodId,
                    userId: mock.userId,
                    eating: eating,
                    condition: condition,
                    costPerformance: costPerformance,
                    storageEase: storageEase,
                    repurchase: repurchase,
                    comment: mock.comment,
                    isReviewPublic: mock.isReviewPublic,
                    timestamp: mock.timestamp,
                    ratings: mock.ratings
                )
                return EvaluationWithFood(evaluation: eval, dogFood: food)
            }
        self.items = evs
        self.isLoading = false
    }
}

// MARK: - HeaderCountRow（DogDetailView専用に統合）
private struct HeaderCountRow: View {
    let dog: DogProfile
    let count: Int
    @Binding var viewMode: DogDetailView.ViewMode

    var body: some View {
        HStack(spacing: 12) {

            // 🐶 プロフィール
            DogAvatarView(dog: dog, size: 56)
                .frame(width: 56, height: 56)
                .overlay(
                    Circle()
                        .stroke(_headerGenderBorderColor(dog.gender), lineWidth: 2)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(dog.name)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: 8) {
                    _HeaderTag(text: dog.breed)
                        .layoutPriority(1)

                    if let age = _headerAgeString(from: dog.birthDate) {
                        _HeaderTag(text: age)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Spacer()

            /// ⭐ ここがボタンになる → 表示切り替え
            Button {
                let next: DogDetailView.ViewMode = (viewMode == .calendar) ? .list : .calendar
                Analytics.logEvent("dog_detail_mode_toggle", parameters: [
                    "dog_id": dog.id ?? "",
                    "from": (viewMode == .calendar) ? "calendar" : "list",
                    "to": (next == .calendar) ? "calendar" : "list"
                ])
                withAnimation(.spring()) {
                    viewMode = next
                }
            } label: {
                _HeaderStatPill(
                    title: (viewMode == .calendar) ? "一覧表示に切替" : "カレンダーに切替"
                )
            }
            .buttonStyle(.plain)
            .frame(minWidth: 120)
        }
    }
}

// MARK: UI小物
private struct _HeaderTag: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color(.systemGray6)))
    }
}

private struct _HeaderStatPill: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundColor(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.9)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.systemGray6))
            )
    }
}

private func _headerGenderBorderColor(_ gender: String) -> Color {
    let isFemale = gender.contains("女") || gender.contains("メス")
    return isFemale ? Color(red: 0.55, green: 0.11, blue: 0.10)
                    : Color(red: 0.05, green: 0.12, blue: 0.23)
}

private func _headerAgeString(from birth: Date) -> String? {
    let comp = Calendar.current.dateComponents([.year, .month], from: birth, to: Date())
    guard let y = comp.year, let m = comp.month else { return nil }
    if y <= 0 { return "\(m)か月" }
    return m == 0 ? "\(y)歳" : "\(y)歳\(m)か月"
}


// MARK: - Preview
#Preview("DogDetail – Grid Mock") {
    let mockDog = PreviewMockData.dogs.first!

    DogDetailView(dog: mockDog) {
        print("🔙 戻る（プレビュー）")
    }
    .environmentObject(MainTabRouter())
    .environmentObject(DogProfileViewModel())
}

