import SwiftUI

// MARK: - RangeSlider (single bar, two thumbs)

struct RangeSlider: View {
    @Binding var lowerValue: Double
    @Binding var upperValue: Double

    let range: ClosedRange<Double>
    let step: Double
    let accent: Color

    @State private var draggingLower = false
    @State private var draggingUpper = false

    private var trackHeight: CGFloat { 6 }
    private var thumbSize: CGFloat { 22 }

    var body: some View {
        GeometryReader { geo in
            let width = max(1, geo.size.width - thumbSize)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.systemGray5))
                    .frame(height: trackHeight)
                    .padding(.horizontal, thumbSize / 2)

                Capsule()
                    .fill(accent.opacity(0.85))
                    .frame(
                        width: selectedWidth(totalWidth: width),
                        height: trackHeight
                    )
                    .offset(x: selectedOffset(totalWidth: width) + thumbSize / 2)

                thumb(isActive: draggingLower)
                    .offset(x: xPosition(for: lowerValue, totalWidth: width))
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                draggingLower = true
                                let newValue = valueFromLocation(value.location.x, totalWidth: width)
                                lowerValue = min(newValue, upperValue)
                            }
                            .onEnded { _ in
                                draggingLower = false
                            }
                    )

                thumb(isActive: draggingUpper)
                    .offset(x: xPosition(for: upperValue, totalWidth: width))
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                draggingUpper = true
                                let newValue = valueFromLocation(value.location.x, totalWidth: width)
                                upperValue = max(newValue, lowerValue)
                            }
                            .onEnded { _ in
                                draggingUpper = false
                            }
                    )
            }
            .frame(height: max(thumbSize, trackHeight))
        }
    }

    private func thumb(isActive: Bool) -> some View {
        Circle()
            .fill(Color(.systemBackground))
            .frame(width: thumbSize, height: thumbSize)
            .overlay(
                Circle().stroke(isActive ? accent : Color(.systemGray3), lineWidth: isActive ? 2 : 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
    }

    private func clamp(_ v: Double) -> Double {
        min(max(v, range.lowerBound), range.upperBound)
    }

    private func snap(_ v: Double) -> Double {
        guard step > 0 else { return v }
        let snapped = (v / step).rounded() * step
        return snapped == 0 ? 0 : snapped
    }

    private func normalized(_ v: Double) -> Double {
        let denom = (range.upperBound - range.lowerBound)
        guard denom != 0 else { return 0 }
        return (v - range.lowerBound) / denom
    }

    private func xPosition(for value: Double, totalWidth: CGFloat) -> CGFloat {
        let n = normalized(clamp(value))
        return CGFloat(n) * totalWidth
    }

    private func valueFromLocation(_ x: CGFloat, totalWidth: CGFloat) -> Double {
        let clampedX = min(max(0, x - thumbSize / 2), totalWidth)
        let n = Double(clampedX / totalWidth)
        let raw = range.lowerBound + n * (range.upperBound - range.lowerBound)
        return clamp(snap(raw))
    }

    private func selectedOffset(totalWidth: CGFloat) -> CGFloat {
        xPosition(for: lowerValue, totalWidth: totalWidth)
    }

    private func selectedWidth(totalWidth: CGFloat) -> CGFloat {
        max(0, xPosition(for: upperValue, totalWidth: totalWidth) - xPosition(for: lowerValue, totalWidth: totalWidth))
    }
}
