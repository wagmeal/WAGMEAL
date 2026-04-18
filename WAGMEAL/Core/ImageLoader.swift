import UIKit
import FirebaseStorage

// 画像の簡易メモリキャッシュ
final class StorageImageCache {
    static let shared: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 500                // 画像枚数上限（お好みで）
        c.totalCostLimit = 50 * 1024 * 1024 // 50MB目安（端末次第で調整）
        return c
    }()
}

// Firebase Storage から画像を取得して公開するローダー
final class StorageImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false

    private let imagePath: String
    private let maxSize: Int64

    init(imagePath: String, maxSize: Int64 = 2 * 1024 * 1024) {
        self.imagePath = imagePath
        self.maxSize = maxSize
        if let cached = StorageImageCache.shared.object(forKey: imagePath as NSString) {
            self.image = cached
        }
    }

    func load() {
        if image != nil || isLoading { return }

        #if DEBUG
        // プレビュー時はネットワークしない（プレースホルダを表示）
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return }
        #endif

        isLoading = true
        let ref = Storage.storage().reference(withPath: imagePath)
        ref.getData(maxSize: maxSize) { data, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let data, let img = UIImage(data: data) {
                    StorageImageCache.shared.setObject(img, forKey: self.imagePath as NSString)
                    self.image = img
                } else {
                    // 失敗時は image を nil のまま（呼び出し側でフォールバック表示）
                    if let error { print("❌ Storage getData 失敗 (\(self.imagePath)): \(error.localizedDescription)") }
                }
            }
        }
    }
}

