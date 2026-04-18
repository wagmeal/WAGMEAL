import SwiftUI

struct DogCard: View {
    let dog: DogProfile
    /// いま挙げているドッグフード（外から渡す）
    var currentDogFoods: [DogFood] = []

    /// 「記録を確認する」押下
    var onShowDetail: (() -> Void)? = nil

    /// 「いまのごはん」の各行押下（親側でドッグフード詳細へ遷移させる）
    var onTapCurrentFood: ((DogFood) -> Void)? = nil

    @Namespace private var foodNamespace

    @State private var showEdit = false
    @EnvironmentObject var dogVM: DogProfileViewModel

    var body: some View {
        // 本体カード
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // 左：画像＋編集ボタン（画像の下に配置・文字のみ）
                VStack(spacing: 6) {
                    DogAvatarView(dog: dog, size: 72)
                        .frame(width: 72, height: 72)
                        .overlay(
                            Circle()
                                .stroke(borderColor(for: dog.gender), lineWidth: 2) // 性別で色分け
                        )

                    Button("編集") {
                        showEdit = true
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.plain)           // 文字のみ
                    .padding(.top, 2)
                    .foregroundColor(Color.gray)
                    .contentShape(Rectangle())     // 文字だけでもタップ範囲を確保
                }
                .frame(width: 80, alignment: .center)

                // 右：名前・犬種・年齢タグ
                VStack(alignment: .leading, spacing: 6) {
                    Text(dog.name)
                        .font(.title3.weight(.semibold))

                    ViewThatFits(in: .horizontal) {
                        // まずは横並びで表示を試す
                        HStack(alignment: .top, spacing: 8) {
                            TagView(text: dog.breed, maxLines: 2)
                                .layoutPriority(1)

                            if let age = ageString(from: dog.birthDate) {
                                TagView(text: age, maxLines: 1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                        }

                        // 横が厳しい場合は縦並びにフォールバック（溢れ防止）
                        VStack(alignment: .leading, spacing: 6) {
                            TagView(text: dog.breed, maxLines: 2)

                            if let age = ageString(from: dog.birthDate) {
                                TagView(text: age, maxLines: 1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                    }
                    .padding(.top, 2)
                }
                Spacer()
            }

            Divider().padding(.vertical, 4)

            // いま挙げてるドッグフード
            VStack(alignment: .leading, spacing: 10) {
                Text("いま食べているごはん")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)

                if currentDogFoods.isEmpty {
                    Text("記録がありません")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 6)
                } else {
                    VStack(spacing: 10) {
                        ForEach(currentDogFoods) { food in
                            let matchedID = food.id ?? food.imagePath

                            Button {
                                onTapCurrentFood?(food)
                            } label: {
                                HStack(spacing: 10) {
                                    DogFoodImageView(
                                        imagePath: food.imagePath,
                                        storagePath: food.storagePath,
                                        matchedID: matchedID,
                                        namespace: foodNamespace
                                    )
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                    VStack(alignment: .leading, spacing: 2) {
                                        // 1行目：ブランド名
                                        if let brand = food.brand, !brand.isEmpty {
                                            Text(brand)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                        // 2行目：ドッグフード名
                                        Text(food.name)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                    }

                                    Spacer(minLength: 0)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Divider().padding(.vertical, 4) // ボタンの上にDivider

            // カード内：詳細へ（角丸の長方形ボタン）
            HStack {
                Spacer()
                Button {
                    onShowDetail?()
                } label: {
                    Text("記録を確認する")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .foregroundColor(Color(red: 184/255, green: 164/255, blue: 144/255))
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(.systemGray6))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)
        )
        .padding(.vertical, 6)
        .sheet(isPresented: $showEdit) {
            EditDogView(dog: dog)
                .environmentObject(dogVM)
        }
    }

    // MARK: - Helpers
    private func ageString(from birth: Date) -> String? {
        let comp = Calendar.current.dateComponents([.year, .month], from: birth, to: Date())
        guard let y = comp.year, let m = comp.month else { return nil }
        if y <= 0 { return "\(m)か月" }
        return m == 0 ? "\(y)歳" : "\(y)歳\(m)か月"
    }

    private func borderColor(for gender: String) -> Color {
        // 女の子 → えんじ / 男の子 → 紺
        gender.contains("女") ? .enji : .kon
    }
}

// 共通UIパーツ
private struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack(spacing: 8) {
            Text(label).foregroundColor(.secondary)
            Spacer(minLength: 8)
            Text(value)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TagView: View {
    let text: String
    var maxLines: Int = 1

    var body: some View {
        Text(text)
            .font(.caption)
            .lineLimit(maxLines)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemGray6))
            )
    }
}

// MARK: - Custom Colors
extension Color {
    static let enji = Color(red: 0.55, green: 0.11, blue: 0.10)  // ≒ #8C1C13
    static let kon  = Color(red: 0.05, green: 0.12, blue: 0.23)  // ≒ #0E1E3A
}


// MARK: - Previews（遷移つきラッパー）

private struct DogCardPreviewWrapper: View {
    @State private var path: [DogProfile] = []
    let dog = PreviewMockData.dogs.first!

    @StateObject private var foodVM = DogFoodViewModel(mockData: true)

    // いまのごはん（プレビュー用）
    private var currentFoods: [DogFood] {
        Array(foodVM.dogFoods.prefix(2))
    }

    var body: some View {
        NavigationStack(path: $path) {
            DogCard(
                dog: dog,
                currentDogFoods: currentFoods,
                onShowDetail: { path.append(dog) },
                onTapCurrentFood: nil
            )
            .environmentObject(DogProfileViewModel(mockDogs: PreviewMockData.dogs))
            .padding()
            .background(Color(.systemGroupedBackground))
            .navigationTitle("DogCard Preview")
            .navigationDestination(for: DogProfile.self) { pushedDog in
                DogDetailView(
                    dog: pushedDog,
                    onClose: { path.removeLast() }   // ← これを渡す
                )
            }
        }
    }
}

#Preview("DogCard – Single (push)") {
    DogCardPreviewWrapper()
}


// 複数カード版：選択した犬で遷移
private struct DogCardListPreviewWrapper: View {
    @State private var path: [DogProfile] = []
    let dogs = PreviewMockData.dogs

    @StateObject private var foodVM = DogFoodViewModel(mockData: true)

    // いまのごはん（プレビュー用）
    private var currentFoods: [DogFood] {
        Array(foodVM.dogFoods.prefix(2))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(dogs) { dog in
                        DogCard(
                            dog: dog,
                            currentDogFoods: currentFoods,
                            onShowDetail: { path.append(dog) },
                            onTapCurrentFood: nil
                        )
                        .environmentObject(DogProfileViewModel(mockDogs: PreviewMockData.dogs))
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("DogCard List")
            .navigationDestination(for: DogProfile.self) { pushedDog in
                DogDetailView(
                    dog: pushedDog,
                    onClose: { path.removeLast() }   // ← これを渡す
                )
            }
        }
    }
}

#Preview("DogCard – List (push)") {
    DogCardListPreviewWrapper()
}
