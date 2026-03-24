import SwiftUI

struct DogAvatarView: View {
    let dog: DogProfile
    var size: CGFloat = 72
    
    @StateObject private var loader: StorageImageLoader
    
    init(dog: DogProfile, size: CGFloat = 72) {
        self.dog = dog
        self.size = size
        // 既存の StorageImageLoader を使用（getData→UIImageキャッシュ）
        _loader = StateObject(
            wrappedValue: StorageImageLoader(imagePath: dog.imagePath ?? "", maxSize: 2 * 1024 * 1024)
        )
    }
    
    var body: some View {
        ZStack {
            if let path = dog.imagePath, !path.isEmpty {
                contentFromLoader
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 1))
        .onAppear {
            if let path = dog.imagePath, !path.isEmpty {
                loader.load()
            }
        }
        .id(dog.imagePath ?? "nil") // パス変更に対応
    }
    
    private var contentFromLoader: some View {
        Group {
            if let img = loader.image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill() // 丸の中でトリミング
            } else if loader.isLoading {
                ProgressView()
            } else {
                placeholder // 読み込み失敗時はプレースホルダへ
            }
        }
    }
    
    private var placeholder: some View {
        Group {
            if let asset = assetName(for: dog.sizeCategory) {
                // シルエット画像＋円グレー背景
                ZStack {
                    Circle().fill(Color(.systemGray6))   // ← 円全体にグレーを敷く
                    Image(asset)
                        .resizable()
                        .scaledToFit()
                        .padding(size * 0.2)
                }
            } else {
                // 最終フォールバック：頭文字
                Circle()
                    .fill(LinearGradient(colors: [Color(.systemTeal), Color(.systemBlue)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(
                        Text(String(dog.name.prefix(1)))
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)
                    )
            }
        }
    }
    
    private func assetName(for sizeCategory: String) -> String? {
        // 例: "小型犬" / "中型犬" / "大型犬"
        if sizeCategory.contains("小") { return "smalldog" }
        if sizeCategory.contains("中") { return "middledog" }
        if sizeCategory.contains("大") { return "bigdog" }
        return nil
    }
}


