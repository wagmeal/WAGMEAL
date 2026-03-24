import SwiftUI
// import FirebaseStorage ← これはもう不要なので削除

struct DogFoodImageView: View {
    let imagePath: String          // Rakuten 画像URL or ローカル画像名
    let matchedID: String          // 今後 matchedGeometryEffect で使いたくなったとき用
    let namespace: Namespace.ID

    var body: some View {
        ZStack {
            if let url = URL(string: imagePath) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()

                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()

                    case .failure:
                        // フォールバック：ローカル画像 or 失敗用画像
                        fallbackImage

                    @unknown default:
                        fallbackImage
                    }
                }
            } else {
                // URL 文字列として不正だった場合
                fallbackImage
            }
        }
        .aspectRatio(1, contentMode: .fit) // 正方形タイル
        .clipped()
    }

    /// フォールバック用画像（ローカル → それもなければ imagefail2）
    private var fallbackImage: some View {
        Group {
            if let local = UIImage(named: imagePath) {
                Image(uiImage: local)
                    .resizable()
                    .scaledToFit()
            } else {
                Image("imagefail2")
                    .resizable()
                    .scaledToFit()
            }
        }
    }
}
