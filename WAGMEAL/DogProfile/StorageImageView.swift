import SwiftUI

struct StorageImageView: View {
    let imagePath: String?
    var width: CGFloat = 72
    var height: CGFloat = 72
    var contentMode: ContentMode = .fill
    var cornerRadius: CGFloat = 12
    var placeholderSystemImage: String = "plus"
    var maxSize: Int64 = 2 * 1024 * 1024

    @StateObject private var loader: StorageImageLoader

    init(imagePath: String?,
         width: CGFloat = 72,
         height: CGFloat = 72,
         contentMode: ContentMode = .fill,
         cornerRadius: CGFloat = 12,
         placeholderSystemImage: String = "plus",
         maxSize: Int64 = 2 * 1024 * 1024) {
        self.imagePath = imagePath
        self.width = width
        self.height = height
        self.contentMode = contentMode
        self.cornerRadius = cornerRadius
        self.placeholderSystemImage = placeholderSystemImage
        self.maxSize = maxSize

        _loader = StateObject(
            wrappedValue: StorageImageLoader(imagePath: imagePath ?? "", maxSize: maxSize)
        )
    }

    var body: some View {
        ZStack {
            if let img = loader.image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if loader.isLoading {
                ProgressView()
            } else {
                Image(systemName: placeholderSystemImage)
                    .resizable()
                    .scaledToFit()
                    .padding(14)
                    .foregroundColor(.gray)
                    .background(Color(.systemGray6))
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear {
            if let p = imagePath, !p.isEmpty { loader.load() }
        }
        // これがポイント：path が変わったら View を作り直し、Loader も作り直す
        .id(imagePath ?? "nil")
    }
}
