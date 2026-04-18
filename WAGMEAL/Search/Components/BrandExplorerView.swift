import SwiftUI
import FirebaseAnalytics

// MARK: - Brand Explorer

struct BrandCircleImageTile: View {
    let imagePath: String?
    let storagePath: String?
    let size: CGFloat
    let imageReloadKey: UUID

    var body: some View {
        ZStack {
            let safeImagePath = imagePath ?? ""
            let safeStoragePath = storagePath

            if safeImagePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               (safeStoragePath ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Image("imagefail2")
                    .resizable()
                    .scaledToFit()
            } else {
                ResolvedDogFoodImageView(
                    storagePath: safeStoragePath,
                    imagePath: safeImagePath,
                    taskID: "brand-\(safeStoragePath ?? safeImagePath)-\(imageReloadKey.uuidString)"
                ) { image in
                    image
                        .resizable()
                        .scaledToFit()
                } placeholder: {
                    ProgressView()
                } fallback: {
                    Image("imagefail2")
                        .resizable()
                        .scaledToFit()
                }
            }
        }
        .frame(width: size, height: size)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(Circle())
        .overlay(
            Circle().stroke(Color(uiColor: .tertiaryLabel), lineWidth: 0.5)
        )
    }
}

struct BrandExplorerView: View {
    let brands: [String]
    let counts: [String: Int]
    let totalCount: Int
    let imageReloadKey: UUID

    let imageProvider: (String) -> (imagePath: String?, storagePath: String?)

    let onTapAll: () -> Void
    let onTap: (String) -> Void

    private let columns: [GridItem] = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ブランドから探す")
                .font(.headline)
                .padding(.leading, 2)

            LazyVGrid(columns: columns, spacing: 16) {
                BrandCard(
                    brand: "すべて",
                    count: totalCount,
                    imagePath: nil,
                    storagePath: nil,
                    imageReloadKey: imageReloadKey
                ) {
                    Analytics.logEvent("brand_select", parameters: [
                        "brand": "all",
                        "from_screen": "search_results"
                    ])
                    onTapAll()
                }

                ForEach(brands, id: \.self) { brand in
                    let provided = imageProvider(brand)
                    let imagePath = provided.imagePath
                    let storagePath = provided.storagePath

                    BrandCard(
                        brand: brand,
                        count: counts[brand] ?? 0,
                        imagePath: imagePath,
                        storagePath: storagePath,
                        imageReloadKey: imageReloadKey
                    ) {
                        Analytics.logEvent("brand_select", parameters: [
                            "brand": brand,
                            "from_screen": "search_results"
                        ])
                        onTap(brand)
                    }
                }
            }
            .padding(.top, 4)

            Text("プルダウンでドッグフード情報を更新")
                .font(.footnote)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

struct BrandCard: View {
    let brand: String
    let count: Int
    let imagePath: String?
    let storagePath: String?
    let imageReloadKey: UUID
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                if brand == "すべて" {
                    ZStack {
                        Circle()
                            .fill(Color.clear)

                        Image("Applogoreverse")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                    }
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color(.systemGray3), lineWidth: 0.5)
                    )
                } else {
                    BrandCircleImageTile(
                        imagePath: imagePath,
                        storagePath: storagePath,
                        size: 96,
                        imageReloadKey: imageReloadKey
                    )
                }

                VStack(spacing: 2) {
                    Text(brand)
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity)
                    Text("\(count)件")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
