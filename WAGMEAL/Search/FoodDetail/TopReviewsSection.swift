import SwiftUI
import Foundation

struct TopReviewsSection: View {
    let dogFoodID: String
    let dogFood: DogFood
    let topReviews: [Evaluation]
    let totalCount: Int
    var reviewCardCaptionStyle: ReviewCard.RatingCaptionStyle = .compact
    @State private var showAll = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最新のレビュー")
                .font(.headline)

            if topReviews.isEmpty {
                Text("まだレビューがありません")
                    .font(.footnote)
                    .foregroundColor(.gray)
            } else {
                let top3 = Array(topReviews.prefix(3))
                VStack(spacing: 30) {
                    ForEach(top3.indices, id: \.self) { idx in
                        let ev = top3[idx]
                        let ageText = ev.dogAgeTextAtEvaluation
                        ReviewCard(e: ev, ageText: ageText, captionStyle: reviewCardCaptionStyle)
                    }

                    if totalCount >= 4 {
                        Button {
                            showAll = true
                        } label: {
                            HStack(spacing: 4) {
                                Text("すべての評価を見る（\(totalCount)件）")
                                Image(systemName: "chevron.right")
                                    .font(.subheadline)
                            }
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.top, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showAll) {
                            NavigationStack {
                                AllEvaluationsView(dogFoodID: dogFoodID, dogFood: dogFood)
                            }
                        }
                    }
                }
            }
        }
        .padding(.top, 8)
    }
}

#Preview("TopReviewsSection – Mock") {
    // MocData から DogFood と評価を作る
    let mockEval = PreviewMockData.evaluations.first!
    let mockFood = PreviewMockData.dogFood.first { $0.id == mockEval.dogFoodId }!

    let sameFoodEvals = PreviewMockData.evaluations
        .filter { $0.dogFoodId == mockEval.dogFoodId }
        .map { Evaluation(fromMock: $0) }

    TopReviewsSection(
        dogFoodID: mockEval.dogFoodId,
        dogFood: mockFood,
        topReviews: Array(sameFoodEvals.prefix(3)),
        totalCount: sameFoodEvals.count,
        reviewCardCaptionStyle: .compact
    )
    .padding()
}
