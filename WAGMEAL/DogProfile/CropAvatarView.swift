import SwiftUI

struct CropAvatarView: View {
    let original: UIImage
    var onCancel: () -> Void
    var onDone: (UIImage) -> Void   // 正方形で返す（丸表示は呼び出し側でマスク）

    // ユーザー操作状態
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 4.0

    var body: some View {
        GeometryReader { geo in
            let screen = geo.size
            let cropDiameter = min(screen.width, screen.height) * 0.82

            let imgW = original.size.width
            let imgH = original.size.height
            // 円の外接正方形に対する scaledToFill 相当の係数
            let baseFit = cropDiameter / min(imgW, imgH)

            // 現在の表示サイズ（実ピクセル）
            let dispW = imgW * baseFit * scale
            let dispH = imgH * baseFit * scale

            // 円を確実に覆うためのオフセット制限
            let maxX = max(0, (dispW - cropDiameter) / 2)
            let maxY = max(0, (dispH - cropDiameter) / 2)

            ZStack {
                Color.black.ignoresSafeArea()

                // ✅ 画像は画面全体に表示（クリップしない）
                Image(uiImage: original)
                    .resizable()
                    .frame(width: dispW, height: dispH)
                    .position(x: screen.width / 2 + offset.width,
                              y: screen.height / 2 + offset.height)
                    .contentShape(Rectangle())
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = clamp(lastScale * value, minScale, maxScale)
                                offset = CGSize(
                                    width: clamp(offset.width, -maxX,  maxX),
                                    height: clamp(offset.height, -maxY, maxY)
                                )
                            }
                            .onEnded { _ in
                                lastScale = scale
                                offset = CGSize(
                                    width: clamp(offset.width, -maxX,  maxX),
                                    height: clamp(offset.height, -maxY, maxY)
                                )
                                lastOffset = offset
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { g in
                                offset = CGSize(
                                    width: clamp(lastOffset.width + g.translation.width,  -maxX,  maxX),
                                    height: clamp(lastOffset.height + g.translation.height, -maxY,  maxY)
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                    .onTapGesture(count: 2) {
                        if scale < 1.6 {
                            scale = min(2.5, maxScale)
                        } else {
                            scale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        }
                        lastScale = scale
                    }

                // ✅ 外側は半透明グレー（even-oddで円だけ穴を開ける）
                Path { p in
                    p.addRect(CGRect(origin: .zero, size: screen))
                    let circle = CGRect(
                        x: (screen.width - cropDiameter) / 2,
                        y: (screen.height - cropDiameter) / 2,
                        width: cropDiameter, height: cropDiameter
                    )
                    p.addEllipse(in: circle)
                }
                .fill(Color.gray.opacity(0.45), style: FillStyle(eoFill: true))
                .allowsHitTesting(false)

                // 円の輪郭（上から白線）
                Circle()
                    .stroke(Color.white.opacity(0.95), lineWidth: 2)
                    .frame(width: cropDiameter, height: cropDiameter)
                    .position(x: screen.width / 2, y: screen.height / 2)
                    .allowsHitTesting(false)

                // ヘッダー
                VStack {
                    HStack {
                        Button("キャンセル", action: onCancel).foregroundColor(.blue)
                        Spacer()
                        Text("アバターを調整").font(.headline).foregroundColor(.white)
                        Spacer()
                        Button("完了") {
                            let exported = renderSquare(
                                exportSize: 600,
                                cropDiameter: cropDiameter,
                                baseFit: baseFit
                            )
                            onDone(exported)
                        }
                        .foregroundColor(.blue).font(.headline)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    Spacer()
                }
            }
            .onAppear {
                // 初期状態：円をちょうど覆う
                scale = 1.0
                lastScale = 1.0
                offset = .zero
                lastOffset = .zero
            }
        }
    }

    private func clamp<T: Comparable>(_ v: T, _ lo: T, _ hi: T) -> T { max(lo, min(v, hi)) }

    /// 現在の表示・位置関係そのままに正方形で書き出し
    private func renderSquare(exportSize: CGFloat, cropDiameter: CGFloat, baseFit: CGFloat) -> UIImage {
        let k = exportSize / cropDiameter
        let imgW = original.size.width
        let imgH = original.size.height
        let dispW = imgW * baseFit * scale
        let dispH = imgH * baseFit * scale

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: exportSize, height: exportSize))
        return renderer.image { ctx in
            UIColor.clear.setFill()
            ctx.fill(CGRect(origin: .zero, size: CGSize(width: exportSize, height: exportSize)))
            // 画面中心ベース + offset を k 倍して配置
            let origin = CGPoint(
                x: (exportSize - dispW * k) / 2 + offset.width * k,
                y: (exportSize - dispH * k) / 2 + offset.height * k
            )
            original.draw(in: CGRect(origin: origin, size: CGSize(width: dispW * k, height: dispH * k)))
        }
    }
}
