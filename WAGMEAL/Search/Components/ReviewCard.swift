import SwiftUI
import Foundation

struct ReadOnlyStarRatingView: View {
    let rating: Double      // 0.0...5.0
    var size: CGFloat = 16
    private let maxStars = 5
    private var clamped: Double { max(0, min(rating, Double(maxStars))) }

    var body: some View {
        let spacing: CGFloat = 4
        let totalWidth = size * CGFloat(maxStars) + spacing * CGFloat(maxStars - 1)
        let full = floor(clamped)
        let partial = clamped - full
        let fillWidth = CGFloat(full) * (size + spacing) + CGFloat(partial) * size

        ZStack {
            HStack(spacing: spacing) {
                ForEach(0..<maxStars, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                        .foregroundStyle(.white)
                }
            }

            HStack(spacing: spacing) {
                ForEach(0..<maxStars, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                        .foregroundStyle(.yellow)
                }
            }
            .frame(width: totalWidth, alignment: .leading)
            .mask(
                HStack(spacing: 0) {
                    Rectangle().frame(width: fillWidth)
                    Spacer(minLength: 0)
                }
                .frame(width: totalWidth)
            )

            HStack(spacing: spacing) {
                ForEach(0..<maxStars, id: \.self) { _ in
                    Image(systemName: "star")
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                        .foregroundStyle(.yellow)
                }
            }
        }
        .frame(width: totalWidth, height: size)
    }
}

#Preview("ReviewCard – Compact") {
    let mock = PreviewMockData.evaluations.first!
    let eval = Evaluation(fromMock: mock)

    ReviewCard(
        e: eval,
        ageText: "2歳",
        captionStyle: .compact
    )
    .padding()
    .background(Color(.systemGray6))
}

#Preview("ReviewCard – With Caption") {
    let mock = PreviewMockData.evaluations.first!
    let eval = Evaluation(fromMock: mock)

    ReviewCard(
        e: eval,
        ageText: "2歳",
        captionStyle: .withCaption
    )
    .padding()
    .background(Color(.systemGray6))
}

struct ReviewCard: View {
    let e: Evaluation
    var ageText: String? = nil

    enum RatingCaptionStyle {
        case compact      // 項目名 + 星のみ（解説なし）
        case withCaption  // 項目名 + 星 + 解説
    }

    var captionStyle: RatingCaptionStyle = .compact

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            VStack(alignment: .leading, spacing: 4) {
                ratingRow(label: "食いつき", value: Double(e.eating), sublabel: "食べるスピード・残しやすさ")
                ratingRow(label: "体調", value: Double(e.condition), sublabel: "便・皮膚・涙やけ・元気さなど")
                ratingRow(label: "コスパ", value: Double(e.costPerformance), sublabel: "価格に対する満足度")
                ratingRow(label: "保存のしやすさ", value: Double(e.storageEase), sublabel: "袋・保管のしやすさなど")
                ratingRow(label: "また買いたい", value: Double(e.repurchase), sublabel: "総合的に見てまた買いたいか")
            }

            Divider()
                .background(Color(.systemGray4))

            if (e.isReviewPublic ?? true),
               let comment = e.comment,
               !comment.isEmpty {
                Text(comment)
                    .font(.body)
                    .foregroundColor(.primary)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    if let ageText {
                        Text("\(e.breed) | \(ageText)")
                    } else {
                        Text(e.breed)
                    }
                }
                .font(.footnote)
                .foregroundColor(.secondary)

                HStack {
                    Text(Self.fmtDate(e.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.white))
        )
    }

    private func ratingRow(label: String, value: Double, sublabel: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                if captionStyle == .withCaption, let sublabel {
                    Text(sublabel)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            Spacer(minLength: 8)
            ReadOnlyStarRatingView(rating: value, size: 16)
        }
    }

    private static func fmtDate(_ date: Date?) -> String {
        guard let d = date else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy/MM/dd"
        return f.string(from: d)
    }
}
