import SwiftUI

/// 0.0〜5.0 を「n.0 で n 個満タン」にする星表示
/// 見た目：白塗りベース＋黄色アウトライン、右から黄色で充填
struct FractionalStarRatingView: View {
    let rating: Double          // 0.0〜5.0
    var size: CGFloat = 18
    var spacing: CGFloat = 4
    private let maxStars = 5
    var fillFromRight: Bool = false

    private var clampedRating: Double {
        max(0, min(rating, Double(maxStars)))
    }
    private var totalWidth: CGFloat {
        size * CGFloat(maxStars) + spacing * CGFloat(maxStars - 1)
    }
    /// ★「n.0でn個満タン」になる幅
    private var fillWidth: CGFloat {
        let full = floor(clampedRating)                 // 0,1,2,3,4,5
        let partial = clampedRating - full              // 0.0〜1.0
        // 完了した星の幅（星+隙間）＋ 部分星の幅（星の幅だけ）
        let fullWidth = CGFloat(full) * (size + spacing)
        let partialWidth = CGFloat(partial) * size
        return fullWidth + partialWidth
    }

    var body: some View {
        ZStack {
            // 1) 白塗りの星（土台）
            HStack(spacing: spacing) {
                ForEach(0..<maxStars, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                }
            }
            .foregroundStyle(.white)

            // 2) 黄色の塗り
            HStack(spacing: spacing) {
                ForEach(0..<maxStars, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                }
            }
            .foregroundStyle(.yellow)
            .frame(width: totalWidth, alignment: .leading)
            .mask(
                HStack(spacing: 0) {
                    if fillFromRight {
                        Spacer(minLength: 0)
                        Rectangle().frame(width: fillWidth)
                    } else {
                        Rectangle().frame(width: fillWidth)
                        Spacer(minLength: 0)
                    }
                }
                .frame(width: totalWidth)
            )

            // 3) 黄色のアウトライン
            HStack(spacing: spacing) {
                ForEach(0..<maxStars, id: \.self) { _ in
                    Image(systemName: "star")
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                }
            }
            .foregroundStyle(.yellow)
        }
        .frame(width: totalWidth, height: size)
    }
}

/// 1行で「左：タイトル」｜「右：数値＋星（右端寄せ）」を表示
struct RatingRow: View {
    let title: String?
    let value: Double?          // 0.0〜5.0
    var starSize: CGFloat = 18
    var numberWidth: CGFloat = 38

    private var formatted: String {
        guard let v = value else { return "" }
        return String(format: "%.1f", v)
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title ?? "")
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                Text(formatted)
                    .font(.headline)
                    .monospacedDigit()
                    .frame(width: numberWidth, alignment: .trailing)
                FractionalStarRatingView(rating: value ?? 0, size: starSize)
            }
            .fixedSize()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title ?? "平均評価")
        .accessibilityValue(formatted)
    }
}
