import SwiftUI

// MARK: - Extensions

extension DogFood {
    /// 詳細遷移やmatchedGeometryEffect用の安定ID
    var stableID: String { id ?? imagePath }
}

extension DogFood {
    /// 未設定時は空文字を返す安全なブランド表示用プロパティ
    var brandNonEmpty: String { brand?.isEmpty == false ? brand! : "" }
}

// MARK: - SearchResultsView

struct SearchResultsView: View {
    @ObservedObject var viewModel: DogFoodViewModel
    @Binding var selectedDogID: String?
    let dogs: [DogProfile]

    @Namespace private var namespace
    @State private var selectedDogFood: DogFood? = nil
    @State private var selectedMatchedID: String? = nil   // アニメ用に安定ID保持
    @State private var showDetail = false
    @FocusState private var isSearchFocused: Bool

    // 現在選択されているわんちゃん
    private var selectedDog: DogProfile? {
        guard let id = selectedDogID else { return nil }
        return dogs.first { $0.id == id }
    }

    private let columns: [GridItem] = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 🔍 検索バー（SearchBarView 側は onChange でリアルタイム反映）
                SearchBarView(
                    searchText: $viewModel.searchText,
                    isSearchActive: $viewModel.isSearchActive,
                    isFocused: $isSearchFocused
                )
                .padding(.top, 6)

                // 🐶 ワンちゃん選択バー
                DogSelectorBar(dogs: dogs, selectedDogID: $selectedDogID)
                    .padding(.top, 4)
                
                // ここに成分フィルタバー
                IngredientFilterBar(selected: $viewModel.selectedIngredientFilters)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)

                ScrollView {
                    let trimmed = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)

                    if !trimmed.isEmpty {
                        // 🔹 入力中/入力済み：検索結果（名前/ブランド）※リアルタイム
                        let items = viewModel.filteredDogFoods

                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(items, id: \.stableID) { dogFood in
                                let matchedID = dogFood.stableID
                                dogFoodCard(dogFood, matchedID: matchedID) {
                                    hideKeyboard()
                                    isSearchFocused = false
                                    withAnimation(.spring()) {
                                        selectedDogFood = dogFood
                                        selectedMatchedID = matchedID
                                        showDetail = true
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 8)

                    } else if viewModel.showAllFoodsFromBrandExplorer {
                        // 🟢 ブランド一覧から「すべて」を選んだとき：全件（成分フィルタ適用）を名前順で表示
                        let items = viewModel.filteredDogFoods.sorted {
                            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                        }

                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(items, id: \.stableID) { dogFood in
                                let matchedID = dogFood.stableID
                                dogFoodCard(dogFood, matchedID: matchedID) {
                                    hideKeyboard()
                                    isSearchFocused = false
                                    withAnimation(.spring()) {
                                        selectedDogFood = dogFood
                                        selectedMatchedID = matchedID
                                        showDetail = true
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 8)

                    } else if isSearchFocused {
                        // 🟢 フォーカス中かつ未入力：全件を名前順で表示（成分フィルタ適用）
                        let items = viewModel.filteredDogFoods.sorted {
                            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                        }

                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(items, id: \.stableID) { dogFood in
                                let matchedID = dogFood.stableID
                                dogFoodCard(dogFood, matchedID: matchedID) {
                                    hideKeyboard()
                                    isSearchFocused = false
                                    withAnimation(.spring()) {
                                        selectedDogFood = dogFood
                                        selectedMatchedID = matchedID
                                        showDetail = true
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 8)

                    } else {
                        // 🔸 未入力 & 非フォーカス：ブランド一覧
                        BrandExplorerView(
                            brands: viewModel.allBrands,
                            counts: viewModel.brandCounts,
                            totalCount: viewModel.dogFoods.count,
                            imagePathProvider: { brand in
                                viewModel.dogFoods.first { ($0.brand?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") == brand }?.imagePath
                            },
                            onTapAll: {
                                withAnimation(.spring()) {
                                    viewModel.searchText = ""
                                    viewModel.isSearchActive = true
                                    viewModel.showAllFoodsFromBrandExplorer = true
                                    isSearchFocused = false
                                }
                            },
                            onTap: { brand in
                                withAnimation(.spring()) {
                                    viewModel.showAllFoodsFromBrandExplorer = false
                                    viewModel.search(byBrand: brand)
                                    isSearchFocused = false
                                }
                            }
                        )
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                    }
                }
            }
            .onAppear {
                // 画面表示時、すでに選択されているわんちゃんがいればそのアレルギーでフィルタを初期化
                applyAllergyFilters(for: selectedDog)
            }
            .onChange(of: viewModel.isSearchActive) { active in
                if !active {
                    viewModel.showAllFoodsFromBrandExplorer = false
                }
            }
            .onChange(of: selectedDogID) { _ in
                // わんちゃんの選択/解除に応じて成分フィルタを更新
                applyAllergyFilters(for: selectedDog)
            }

            // 詳細ビュー（オーバーレイ）
            if let dogFood = selectedDogFood, showDetail {
                DogFoodDetailView(
                    dogFood: dogFood,
                    dogs: dogs,
                    namespace: namespace,
                    matchedID: selectedMatchedID ?? (dogFood.id ?? "search-\(dogFood.imagePath)"),
                    isPresented: $showDetail
                )
                .id(selectedMatchedID ?? (dogFood.id ?? "search-\(dogFood.imagePath)"))
                .environmentObject(viewModel)
                .zIndex(1)
                .transition(.move(edge: .trailing))
                .gesture(
                    DragGesture().onEnded { value in
                        if value.translation.width > 100 {
                            withAnimation {
                                showDetail = false
                                selectedDogFood = nil
                            }
                        }
                    }
                )
            }
        }
    }

    /// 選択中のわんちゃんのアレルギー情報から成分フィルタを自動設定
    private func applyAllergyFilters(for dog: DogProfile?) {
        guard let dog = dog else {
            // わんちゃん未選択時は成分フィルタをリセット（全成分許可）
            viewModel.selectedIngredientFilters = []
            return
        }

        var forbidden = Set<IngredientFilter>()

        if dog.allergicChicken ?? false { forbidden.insert(.chicken) }
        if dog.allergicBeef ?? false { forbidden.insert(.beef) }
        if dog.allergicPork ?? false { forbidden.insert(.pork) }
        if dog.allergicLamb ?? false { forbidden.insert(.lamb) }
        if dog.allergicFish ?? false { forbidden.insert(.fish) }
        if dog.allergicEgg ?? false { forbidden.insert(.egg) }
        if dog.allergicDairy ?? false { forbidden.insert(.dairy) }
        if dog.allergicWheat ?? false { forbidden.insert(.wheat) }
        if dog.allergicCorn ?? false { forbidden.insert(.corn) }
        if dog.allergicSoy ?? false { forbidden.insert(.soy) }

        viewModel.selectedIngredientFilters = forbidden
    }

    // MARK: - Card

    private func dogFoodCard(_ dogFood: DogFood, matchedID: String, onTap: @escaping () -> Void) -> some View {
        VStack(spacing: 6) {
            DogFoodImageView(
                imagePath: dogFood.imagePath,
                matchedID: matchedID,
                namespace: namespace
            )
            .id(dogFood.imagePath)   // 画像の更新を安定化

            VStack(alignment: .leading, spacing: 6) {
                Text(dogFood.name)
                    .font(.caption)
                    .lineLimit(2)                          // 最大2行まで表示
                    .multilineTextAlignment(.leading)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity,
                           minHeight: 32,                  // 1行でも2行分の高さを確保して段ズレ防止
                           alignment: .topLeading)
                    .padding(.leading, 8)

                // ★ 評価件数 + ハート（集約VMを参照）
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "ellipsis.message")
                        let count = viewModel.evaluationCount(for: dogFood.id)
                        Text(" \(count.map(String.init) ?? "—")")
                            .redacted(reason: count == nil ? .placeholder : [])
                    }

                    Spacer()

                    Button {
                        if let id = dogFood.id { viewModel.toggleFavorite(dogFoodID: id) }
                    } label: {
                        Image(systemName: viewModel.isFavorite(dogFood.id) ? "heart.fill" : "heart")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.leading, 8)
                .padding(.trailing, 8)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onAppear {
            viewModel.loadEvaluationCountIfNeeded(for: dogFood.id)
        }
    }
}



private struct DogSelectorBar: View {
    let dogs: [DogProfile]
    @Binding var selectedDogID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("わんちゃんを選択")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(dogs) { dog in
                        let isSelected = dog.id == selectedDogID

                        Button {
                            if isSelected {
                                // ONの状態でもう一度押したら未選択状態に戻す
                                selectedDogID = nil
                            } else {
                                selectedDogID = dog.id
                            }
                        } label: {
                            Text(dog.name)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? Color(red: 184/255, green: 164/255, blue: 144/255).opacity(0.2) : Color(.systemGray6))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(isSelected ? Color(red: 184/255, green: 164/255, blue: 144/255) : Color(.systemGray3), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
            }
        }
    }
}

private struct IngredientFilterBar: View {
    @Binding var selected: Set<IngredientFilter>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // タイトル（小さめグレー）
            Text("アレルギー成分で絞り込む")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(IngredientFilter.allCases) { filter in
                        // selected = OFF(除外したい成分) の集合として扱う
                        let isOn = !selected.contains(filter)

                        Button {
                            if isOn {
                                // ON → OFF にする（除外リストに追加）
                                selected.insert(filter)
                            } else {
                                // OFF → ON にする（除外リストから外す）
                                selected.remove(filter)
                            }
                        } label: {
                            Text(filter.label)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(isOn ? Color(.systemGray6) : Color(red: 184/255, green: 164/255, blue: 144/255).opacity(0.2))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(isOn ? Color(.systemGray3) : Color(red: 184/255, green: 164/255, blue: 144/255), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

private struct BrandCircleImageTile: View {
    let imagePath: String?
    let size: CGFloat

    var body: some View {
        ZStack {
            if let path = imagePath, !path.isEmpty, let url = URL(string: path) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()

                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()

                    case .failure:
                        if let local = UIImage(named: path) {
                            Image(uiImage: local)
                                .resizable()
                                .scaledToFit()
                        } else {
                            Image("imagefail2")
                                .resizable()
                                .scaledToFit()
                        }

                    @unknown default:
                        Image("imagefail2")
                            .resizable()
                            .scaledToFit()
                    }
                }
            } else {
                Image("imagefail2")
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: size, height: size)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(Circle())
        .overlay(
            Circle().stroke(Color(uiColor: .tertiaryLabel), lineWidth: 0.5)
        )
    }
}

// MARK: - Brand Explorer

private struct BrandExplorerView: View {
    let brands: [String]
    let counts: [String: Int]
    let totalCount: Int
    let imagePathProvider: (String) -> String?
    let onTapAll: () -> Void
    let onTap: (String) -> Void

    // 3カラム（ZOZO風）
    private let columns: [GridItem] = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ブランドから探す")
                .font(.headline)
                .padding(.leading, 2)

            LazyVGrid(columns: columns, spacing: 16) {
                // 先頭に「すべて」カード
                BrandCard(
                    brand: "すべて",
                    count: totalCount,
                    imagePath: nil
                ) {
                    onTapAll()
                }

                ForEach(brands, id: \.self) { brand in
                    let imagePath = imagePathProvider(brand)
                    BrandCard(
                        brand: brand,
                        count: counts[brand] ?? 0,
                        imagePath: imagePath
                    ) {
                        onTap(brand)
                    }
                }
            }
            .padding(.top, 4)
        }
    }
}

private struct BrandCard: View {
    let brand: String
    let count: Int
    let imagePath: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // 「すべて」だけ固定アイコンを使用
                if brand == "すべて" {
                    ZStack {
                        Circle()
                            .fill(Color.clear)

                        Image("Applogoreverse")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)   // ← 内側だけ小さくする
                    }
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color(.systemGray3), lineWidth: 0.5)
                    )
                } else {
                    BrandCircleImageTile(imagePath: imagePath, size: 96)
                }
                VStack(spacing: 2) {
                    Text(brand)
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity)
                    Text("\(count)件")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    struct Wrapper: View {
        @State private var selectedDogID: String? = nil

        var body: some View {
            let mockViewModel = DogFoodViewModel(mockData: true)
            // ブランドがモック内に無ければ、ブランド一覧は空のまま表示されます。
            mockViewModel.searchText = ""
            mockViewModel.isSearchActive = true

            return SearchResultsView(
                viewModel: mockViewModel,
                selectedDogID: $selectedDogID,
                dogs: PreviewMockData.dogs
            )
        }
    }

    return Wrapper()
}


#if canImport(UIKit)
extension View {
    /// キーボードを強制的に閉じるユーティリティ
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil,
                                        from: nil,
                                        for: nil)
    }
}
#endif
