import SwiftUI
// import FirebaseStorage ← これはもう不要なので削除

struct DogFoodImageView: View {
    let imagePath: String
    let matchedID: String
    let namespace: Namespace.ID

    /// 追加：true=成功 / false=失敗
    var onLoadResult: ((Bool) -> Void)? = nil

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
                            .onAppear { onLoadResult?(true) }

                    case .failure:
                        fallbackImage
                            .onAppear { onLoadResult?(false) }

                    @unknown default:
                        fallbackImage
                            .onAppear { onLoadResult?(false) }
                    }
                }
            } else {
                fallbackImage
                    .onAppear { onLoadResult?(false) }
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
