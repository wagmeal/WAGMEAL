import SwiftUI

struct MyDogView: View {
    @Binding var selectedDogID: String?
    @ObservedObject var dogVM: DogProfileViewModel
    @EnvironmentObject var authVM: AuthViewModel

    @State private var isShowingDogManagement = false
    @State private var selectedDogForDetail: DogProfile? = nil
    @State private var showDetail = false
    @State private var dogToDelete: DogProfile? = nil

    private var visibleDogs: [DogProfile] {
        dogVM.dogs.filter { $0.isDeleted != true }
    }

    // 単一のわんちゃんカード行を切り出してコンパイル負荷を下げる
    @ViewBuilder
    private func dogRow(for dog: DogProfile) -> some View {
        DogCard(dog: dog) {
            withAnimation(.spring()) {
                selectedDogForDetail = dog
                showDetail = true
            }
        }
        .environmentObject(dogVM)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                dogToDelete = dog
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }

    var body: some View {
        ZStack {
            // ===== 本体 =====
            VStack(spacing: 0) {
                List {
                    // 🐶 登録済みのわんちゃん一覧
                    ForEach(visibleDogs, id: \.id) { dog in
                        dogRow(for: dog)
                    }
                    Button {
                        isShowingDogManagement = true
                    } label: {
                        Text("MyDog追加")
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
                .onAppear { dogVM.fetchDogs() }
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
        }
        // DogManagementは従来どおりシートでOK（NavigationStack不要）
        .sheet(isPresented: $isShowingDogManagement) {
            NewDogView(selectedDogID: $selectedDogID, dogVM: dogVM)
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
                    dogVM.softDelete(dog: dog)
                }
                dogToDelete = nil
            }
        } message: { _ in
            Text("評価データは残ります")
        }
        .edgesIgnoringSafeArea(.bottom)
        .background(Color.white)
    }
}

// MARK: - Previews
#Preview("MyDogView – Mock") {
    struct MyDogPreviewWrapper: View {
        @State private var selectedDogID: String? = PreviewMockData.dogs.first?.id
        var body: some View {
            let mockDogVM = DogProfileViewModel(mockDogs: PreviewMockData.dogs)
            let mockAuthVM = AuthViewModel()
            mockAuthVM.isLoggedIn = true
            mockAuthVM.username = "たくみ"

            return MyDogView(
                selectedDogID: $selectedDogID,
                dogVM: mockDogVM
            )
            .environmentObject(mockAuthVM)
            .background(Color(.systemGroupedBackground))
        }
    }
    return MyDogPreviewWrapper()
}

#Preview("MyDogView – Dark") {
    struct MyDogPreviewWrapperDark: View {
        @State private var selectedDogID: String? = PreviewMockData.dogs.first?.id
        var body: some View {
            let mockDogVM = DogProfileViewModel(mockDogs: PreviewMockData.dogs)
            let mockAuthVM = AuthViewModel()
            mockAuthVM.isLoggedIn = true
            mockAuthVM.username = "たくみ"

            return MyDogView(
                selectedDogID: $selectedDogID,
                dogVM: mockDogVM
            )
            .environmentObject(mockAuthVM)
            .background(Color(.systemGroupedBackground))
            .preferredColorScheme(.dark)
        }
    }
    return MyDogPreviewWrapperDark()
}
