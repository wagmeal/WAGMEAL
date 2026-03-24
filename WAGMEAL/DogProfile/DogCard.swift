import SwiftUI

struct DogCard: View {
    let dog: DogProfile
    var onShowDetail: (() -> Void)? = nil

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

                    HStack(spacing: 8) {
                        TagView(text: dog.breed)
                        if let age = ageString(from: dog.birthDate) {
                            TagView(text: age)
                        }
                    }
                    .padding(.top, 2)
                }
                Spacer()
            }

            Divider().padding(.vertical, 4)

            // カード内：詳細へ（角丸の長方形ボタン）
            HStack {
                Spacer()
                Button {
                    onShowDetail?()
                } label: {
                    Text("過去の記録を見る")
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
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(Color(.systemGray6)))
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

    var body: some View {
        NavigationStack(path: $path) {
            DogCard(dog: dog, onShowDetail: { path.append(dog) })
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

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(dogs) { dog in
                        DogCard(dog: dog, onShowDetail: { path.append(dog) })
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
