import SwiftUI

struct StarRatingView: View {

    // ⭐️ サイズプリセット
    enum SizePreset {
        case normal
        case large
    }

    @Binding var rating: Int
    var label: String
    var preset: SizePreset = .normal

    // ⭐️ プリセットからサイズを決定
    private var starSize: CGFloat {
        switch preset {
        case .normal:
            return 18
        case .large:
            return 18
        }
    }

    // ⭐️ プリセットから間隔を決定
    private var starSpacing: CGFloat {
        switch preset {
        case .normal:
            return 8
        case .large:
            return 12
        }
    }

    var body: some View {
        HStack(alignment: .center) {
            Text(label)
                .font(preset == .large ? .headline : .subheadline)

            Spacer()

            HStack(spacing: starSpacing) {
                ForEach(1...5, id: \.self) { index in
                    Image(systemName: index <= rating ? "star.fill" : "star")
                        // 星だけを大きくする（行全体は拡大しない）
                        .font(.system(size: starSize))
                        .foregroundColor(.yellow)
                        // ⭐️ 押しやすさ重視：タップ領域を拡張
                        .padding(.horizontal, 2)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            rating = index
                        }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
