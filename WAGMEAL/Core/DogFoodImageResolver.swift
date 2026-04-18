import SwiftUI
import FirebaseCore
import FirebaseStorage
import UIKit
import ImageIO

// MARK: - Cache

/// StorageのUIImage取得結果をメモして同じ画像の再取得を減らす
/// NSCacheを使うことでメモリ上限（200件 / 50MB）を超えると自動的にエントリが解放される
actor DogFoodUIImageCache {
    static let shared = DogFoodUIImageCache()
    private let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 200
        c.totalCostLimit = 50 * 1024 * 1024 // 50MB
        return c
    }()

    func get(_ key: String) -> UIImage? { cache.object(forKey: key as NSString) }
    func set(_ key: String, _ value: UIImage) { cache.setObject(value, forKey: key as NSString) }
}

// MARK: - Resolver

/// 画像解決ロジック（優先順位：Storage -> Database(URL) -> nil）
struct DogFoodImageResolver {

    /// Xcode Preview 判定（Previewでは FirebaseApp.configure() が走らないことが多い）
    private static var isRunningForPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    enum Resolved {
        case uiImage(UIImage)      // Storage から取得した画像
        case remoteURL(URL)        // 楽天などの http/https URL
    }

    /// サムネイル用途の最大ピクセル（一覧/お気に入り/ランキングの正方形タイル向け）
    /// 大きすぎるとデコードが重く、小さすぎると粗く見えるためバランス値
    private static let thumbnailMaxPixel: CGFloat = 512

    /// Data からダウンサンプリングして UIImage を生成（大きな元画像のデコード負荷を削減）
    private static func downsampledImage(from data: Data, maxPixel: CGFloat, scale: CGFloat = UIScreen.main.scale) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return nil
        }

        let maxDimension = maxPixel * scale
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxDimension)
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    /// 描画前にビットマップを展開しておく（描画時の遅延デコードによるスクロールカクつきを減らす）
    private static func decodedImage(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue

        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return image
        }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let out = ctx.makeImage() else { return image }
        return UIImage(cgImage: out)
    }

    /// `storagePath` があれば Storage からバイナリ取得を優先（UIImage）。
    /// 失敗または未指定の場合は `imagePath`（http/https URL文字列）を返す（AsyncImageで描画）。
    static func resolve(storagePath: String?, imagePath: String) async -> Resolved? {
        // 1) Firebase Storage → UIImage
        if let sp = storagePath?.trimmingCharacters(in: .whitespacesAndNewlines), !sp.isEmpty {
            // Xcode Preview / Firebase未初期化では Storage を触るとクラッシュすることがあるためスキップ
            if !isRunningForPreviews, FirebaseApp.app() != nil {
                let key = "storage:" + sp
                if let cached = await DogFoodUIImageCache.shared.get(key) {
                    return .uiImage(cached)
                }
                do {
                    let data = try await downloadDataFromStorage(path: sp)

                    // 大きい画像をそのままUIImage(data:)すると遅延デコードでスクロールが重くなりやすい
                    // 一覧用途のサイズにダウンサンプルして、さらに事前デコードしてからキャッシュ
                    if let thumb = downsampledImage(from: data, maxPixel: thumbnailMaxPixel) {
                        let decoded = decodedImage(thumb)
                        await DogFoodUIImageCache.shared.set(key, decoded)
                        return .uiImage(decoded)
                    } else if let img = UIImage(data: data) {
                        let decoded = decodedImage(img)
                        await DogFoodUIImageCache.shared.set(key, decoded)
                        return .uiImage(decoded)
                    }
                } catch {
                    // fallthrough
                }
            }
        }

        // 2) Database(URL string) → URL（AsyncImage）
        let trimmed = imagePath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty,
           let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return .remoteURL(url)
        }

        // 3) Not found
        return nil
    }

    private static func downloadDataFromStorage(path: String) async throws -> Data {
        // 二重ガード（resolve側で防いでも念のため）
        if isRunningForPreviews || FirebaseApp.app() == nil {
            throw NSError(domain: "FirebaseNotConfigured", code: -1)
        }

        return try await withCheckedThrowingContinuation { continuation in
            let ref = Storage.storage().reference(withPath: path)
            // 10MB上限（必要なら調整）
            ref.getData(maxSize: 10 * 1024 * 1024) { data, error in
                if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: error ?? NSError(domain: "StorageGetData", code: -1))
                }
            }
        }
    }
}

// MARK: - Shared View

/// 画像の「URL解決」だけを共通化したView
/// 表示の加工（resizable/scale/clip/frame等）は呼び出し側が自由に指定する
struct ResolvedDogFoodImageView<Content: View, Placeholder: View, Fallback: View>: View {

    let storagePath: String?
    let imagePath: String

    /// `.task(id:)` のID（セル再利用/画面切替で取り違えないため）
    let taskID: String

    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    let fallback: () -> Fallback

    @State private var resolved: DogFoodImageResolver.Resolved? = nil
    @State private var didResolve: Bool = false

    var body: some View {
        ZStack {
            switch resolved {
            case .uiImage(let uiImage):
                content(Image(uiImage: uiImage))

            case .remoteURL(let url):
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholder()
                    case .success(let image):
                        content(image)
                    case .failure:
                        fallback()
                    @unknown default:
                        fallback()
                    }
                }

            case .none:
                if didResolve {
                    fallback()
                } else {
                    placeholder()
                }
            }
        }
        .task(id: taskID) {
            await resolve()
        }
    }

    private func resolve() async {
        // reset (UI state) on main
        await MainActor.run {
            resolved = nil
            didResolve = false
        }

        // Heavy work (Storage download / downsample / decode) should NOT run on the main actor.
        let r = await DogFoodImageResolver.resolve(storagePath: storagePath, imagePath: imagePath)
        if Task.isCancelled { return }

        await MainActor.run {
            resolved = r
            didResolve = true
        }
    }
}
