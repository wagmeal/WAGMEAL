import SwiftUI

struct DogFoodImageView: View {
    let imagePath: String
    let storagePath: String?

    let matchedID: String
    let namespace: Namespace.ID
    let enableMatchedGeometry: Bool

    /// pull-to-refreshなど「明示的な再試行」を起こすためのキー（通常は nil でOK）
    let reloadKey: UUID?
    /// true のときだけ reloadKey 変化で再試行する
    let shouldRetry: Bool

    var onLoadResult: ((Bool) -> Void)? = nil

    // ✅ 追加：通知済み判定（スクロールでの再出現で通知を連打しない）
    @State private var lastReportedTaskID: String? = nil
    @State private var lastReportedSuccess: Bool? = nil

    init(
        imagePath: String,
        storagePath: String?,
        matchedID: String,
        namespace: Namespace.ID,
        enableMatchedGeometry: Bool = false,
        reloadKey: UUID? = nil,
        shouldRetry: Bool = false,
        onLoadResult: ((Bool) -> Void)? = nil
    ) {
        self.imagePath = imagePath
        self.storagePath = storagePath
        self.matchedID = matchedID
        self.namespace = namespace
        self.enableMatchedGeometry = enableMatchedGeometry
        self.reloadKey = reloadKey
        self.shouldRetry = shouldRetry
        self.onLoadResult = onLoadResult
    }

    var body: some View {
        // ✅ ResolvedDogFoodImageView に渡す taskID と必ず一致させる
        let effectiveTaskID = shouldRetry
        ? "\(matchedID)-\(reloadKey?.uuidString ?? "retry")"
        : matchedID

        Group {
            if enableMatchedGeometry {
                ResolvedDogFoodImageView(
                    storagePath: storagePath,
                    imagePath: imagePath,
                    taskID: effectiveTaskID
                ) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .matchedGeometryEffect(id: matchedID, in: namespace)
                        .onAppear {
                            // ✅ スクロールでセルが再出現しても親Stateを何度も更新しない
                            if lastReportedTaskID != effectiveTaskID || lastReportedSuccess != true {
                                lastReportedTaskID = effectiveTaskID
                                lastReportedSuccess = true
                                onLoadResult?(true)
                            }
                        }
                } placeholder: {
                    fallbackPlaceholder
                } fallback: {
                    fallbackImage
                        .matchedGeometryEffect(id: matchedID, in: namespace)
                        .onAppear {
                            if lastReportedTaskID != effectiveTaskID || lastReportedSuccess != false {
                                lastReportedTaskID = effectiveTaskID
                                lastReportedSuccess = false
                                onLoadResult?(false)
                            }
                        }
                }
            } else {
                ResolvedDogFoodImageView(
                    storagePath: storagePath,
                    imagePath: imagePath,
                    taskID: effectiveTaskID
                ) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .onAppear {
                            // ✅ スクロールでセルが再出現しても親Stateを何度も更新しない
                            if lastReportedTaskID != effectiveTaskID || lastReportedSuccess != true {
                                lastReportedTaskID = effectiveTaskID
                                lastReportedSuccess = true
                                onLoadResult?(true)
                            }
                        }
                } placeholder: {
                    fallbackPlaceholder
                } fallback: {
                    fallbackImage
                        .onAppear {
                            if lastReportedTaskID != effectiveTaskID || lastReportedSuccess != false {
                                lastReportedTaskID = effectiveTaskID
                                lastReportedSuccess = false
                                onLoadResult?(false)
                            }
                        }
                }
            }
        }
        // ✅ 画像の差し替え時にアニメが入って“瞬き”するのを抑える
        .transaction { $0.animation = nil }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
    }

    private var fallbackPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.secondarySystemFill))
            .overlay {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
    }

    private var fallbackImage: some View {
        Image("imagefail2")
            .resizable()
            .scaledToFit()
    }
}
