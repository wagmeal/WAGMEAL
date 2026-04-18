import SwiftUI
import UIKit

struct DogEvaluationListView: View {
    let items: [EvaluationWithFood]
    let onSelect: (EvaluationWithFood) -> Void

    enum SortKey: String, CaseIterable, Identifiable {
        case date = "日付順"
        case repurchase = "また買いたい順"
        var id: String { rawValue }
    }

    @State private var sortKey: SortKey = .date
    @State private var isDescending: Bool = true

    private var sortedItems: [EvaluationWithFood] {
        let sorted: [EvaluationWithFood]
        switch sortKey {
        case .date:
            // 日付順: 「与え始めた日」を優先。なければ記録作成日（timestamp）。
            // 降順=新しい順 / 昇順=古い順
            sorted = items.sorted {
                let d0 = dateKey($0)
                let d1 = dateKey($1)
                return isDescending ? (d0 > d1) : (d0 < d1)
            }

        case .repurchase:
            // また買いたい: 降順=高い順 / 昇順=低い順（同点は日付で決定）
            sorted = items.sorted {
                if $0.evaluation.repurchase == $1.evaluation.repurchase {
                    let d0 = dateKey($0)
                    let d1 = dateKey($1)
                    return isDescending ? (d0 > d1) : (d0 < d1)
                }
                return isDescending
                ? ($0.evaluation.repurchase > $1.evaluation.repurchase)
                : ($0.evaluation.repurchase < $1.evaluation.repurchase)
            }
        }
        return sorted
    }

    private func dateKey(_ item: EvaluationWithFood) -> Date {
        // 日付順は「与え始めた日」を優先。なければ記録作成日（timestamp）。
        item.evaluation.feedingStartDate ?? item.evaluation.timestamp
    }

    var body: some View {
        VStack(spacing: 0) {
            sortHeader
            listContent
        }
        .background(Color.white.ignoresSafeArea())
    }

    private var sortHeader: some View {
        HStack(spacing: 10) {
            Spacer()

            Menu {
                ForEach(SortKey.allCases) { key in
                    Button {
                        sortKey = key
                    } label: {
                        HStack {
                            if sortKey == key { Image(systemName: "checkmark") }
                            Text(key.rawValue)
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(sortKey.rawValue)
                        .font(.subheadline)
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.caption)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // 降順 / 昇順 切替
            Button {
                withAnimation(.spring()) {
                    isDescending.toggle()
                }
            } label: {
                Image(systemName: isDescending ? "arrow.down" : "arrow.up")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 28)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel("並び順")
                    .accessibilityValue(isDescending ? "降順" : "昇順")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white)
        // 下に薄い余白だけ（線は出さない）
        .padding(.bottom, 4)
    }

    private var listContent: some View {
        List {
            ForEach(sortedItems.indices, id: \.self) { idx in
                let item = sortedItems[idx]
                Section {
                    Button {
                        onSelect(item)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            // 記録作成日（囲いの外）
                            Text("記録作成日：\(dateString(item.evaluation.timestamp))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 2)

                            // 囲い（カード）
                            DogEvaluationRowView(item: item)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color(.systemGray4), lineWidth: 0.6)
                                )
                        }
                        .padding(.bottom, 16)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.white)
                    .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy/MM/dd"
        return f.string(from: date)
    }
}

// MARK: - 1行分のレイアウト
private struct DogEvaluationRowView: View {
    let item: EvaluationWithFood

    // Removed @State properties for resolvedURL and didResolve

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                // ドッグフード画像
                evaluationImage()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // ドッグフード名 ＋ 食べた期間
                VStack(alignment: .leading, spacing: 4) {
                    if !item.dogFood.brandNonEmpty.isEmpty {
                        Text(item.dogFood.brandNonEmpty)
                            .font(.caption)
                            .foregroundColor(Color(red: 184/255, green: 164/255, blue: 144/255))
                            .lineLimit(1)
                    }
                    // ドッグフード名
                    Text(item.dogFood.name)
                        .font(.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        // 1行でも2行分の高さを確保し、1行時は縦方向センターに配置
                        .frame(minHeight: 44, alignment: .center)
                        // 横方向は左寄せを維持
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // ⭐️ また買いたい（5項目の中で総合指標として表示）
                    StarStaticRow(rating: item.evaluation.repurchase, size: 13)
                }

                Spacer(minLength: 0)
            }
            // 食べた期間表示（画像の下 / 囲いの左端から開始）
            Text("\(periodString(for: item.evaluation))")
                .font(.body)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(alignment: .trailing) {
            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.gray)
                .padding(.trailing, 4)
        }
        // 右端の矢印がコンテンツに被らないように余白を確保
        .padding(.trailing, 5)
    }

    // ドッグフード画像（優先順位：Storage -> Database(URL) -> imagefail2）
    @ViewBuilder
    private func evaluationImage() -> some View {
        ResolvedDogFoodImageView(
            storagePath: item.dogFood.storagePath,
            imagePath: item.dogFood.imagePath,
            taskID: item.dogFood.id ?? item.dogFood.imagePath
        ) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            ProgressView()
        } fallback: {
            Image("imagefail2")
                .resizable()
                .scaledToFill()
        }
    }

    // Removed resolveImageURL() and downloadURL(fromStoragePath:) methods

    private func periodString(for ev: Evaluation) -> String {
        let start = ev.feedingStartDate
        let end = ev.feedingEndDate

        // 1) 両方とも記録がない場合
        if start == nil && end == nil {
            return "記録なし"
        }

        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy/MM/dd"

        // 2) start あり / end なし
        if let s = start, end == nil {
            let sStr = f.string(from: s)
            return "\(sStr)〜"
        }

        // 3) start あり / end あり
        if let s = start, let e = end {
            let sStr = f.string(from: s)
            let eStr = f.string(from: e)
            return "\(sStr)〜\(eStr)"
        }

        // 想定外パターン（end のみ）については安全側で「記録なし」とする
        return "記録なし"
    }
}

// MARK: - Yellow star row (read-only)
private struct StarStaticRow: View {
    let rating: Int
    var size: CGFloat = 14

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= rating ? "star.fill" : "star")
                    .font(.system(size: size, weight: .semibold))
                    .foregroundColor(.yellow)
            }
        }
        .accessibilityLabel("また買いたい")
        .accessibilityValue("\(rating) / 5")
    }
}

#Preview("DogEvaluationListView – dog_001") {
    // dog_001 の記録だけを Preview に表示
    let mockItems = PreviewMockData.evaluationItems(dogID: "dog_001")

    DogEvaluationListView(
        items: mockItems,
        onSelect: { _ in }
    )
}
