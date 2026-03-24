// DogForm Support Types
// Place this file in your project if you removed the old DogManagementView/DogEditView
// which previously defined these helpers.

import SwiftUI

// MARK: - Flow row break key + helper
private struct FlowRowBreakKey: LayoutValueKey {
    static let defaultValue: Bool = false
}

public extension View {
    /// Insert this view to force a new row in FlowLayout
    func flowRowBreak(_ newLine: Bool = true) -> some View {
        layoutValue(key: FlowRowBreakKey.self, value: newLine)
    }
}

// MARK: - FlowLayout (iOS 16+)
public struct FlowLayout: Layout {
    public var hSpacing: CGFloat = 8
    public var vSpacing: CGFloat = 8

    public init(hSpacing: CGFloat = 8, vSpacing: CGFloat = 8) {
        self.hSpacing = hSpacing
        self.vSpacing = vSpacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            let isBreak = view[FlowRowBreakKey.self]
            if isBreak && x > 0 {
                x = 0; y += rowH + vSpacing; rowH = 0
            }
            let needNewLine = x > 0 && (x + size.width) > maxWidth
            if needNewLine {
                x = 0; y += rowH + vSpacing; rowH = 0
            }
            x += size.width + (x > 0 ? hSpacing : 0)
            rowH = max(rowH, size.height)
        }
        y += rowH
        return CGSize(width: maxWidth.isFinite ? maxWidth : x, height: y)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            let isBreak = view[FlowRowBreakKey.self]
            if isBreak && x > 0 {
                x = 0; y += rowH + vSpacing; rowH = 0
            }
            let needNewLine = x > 0 && (x + size.width) > maxWidth
            if needNewLine {
                x = 0; y += rowH + vSpacing; rowH = 0
            }
            view.place(
                at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            x += size.width + (x > 0 ? hSpacing : 0)
            rowH = max(rowH, size.height)
        }
    }
}

// MARK: - BreedChip (pill-like selectable tag)
public struct BreedChip: View {
    let label: String
    let isSelected: Bool
    let fontSize: CGFloat
    let onTap: () -> Void

    var hPad: CGFloat = 12
    var vPad: CGFloat = 8
    var corner: CGFloat = 10

    // Beige-ish palette to match your app
    var selectedBackground: Color = Color(red: 0.94, green: 0.89, blue: 0.80)
    var selectedStroke: Color = Color(red: 0.85, green: 0.78, blue: 0.66)
    var unselectedBackground: Color = Color(UIColor.systemGray6)
    var unselectedStroke: Color = Color.gray.opacity(0.35)

    public var body: some View {
        Text(label)
            .font(.system(size: fontSize))
            .lineLimit(1)
            .truncationMode(.tail)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.vertical, vPad)
            .padding(.horizontal, hPad)
            .background(isSelected ? selectedBackground : unselectedBackground)
            .overlay(
                RoundedRectangle(cornerRadius: corner)
                    .stroke(isSelected ? selectedStroke : unselectedStroke,
                            lineWidth: isSelected ? 1.5 : 1)
            )
            .cornerRadius(corner)
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
    }
}

// MARK: - TextFieldChip (inline text field styled like a chip)
public struct TextFieldChip: View {
    @Binding var text: String
    let placeholder: String
    let fontSize: CGFloat
    var width: CGFloat? = nil
    var background: Color = .white
    var hPad: CGFloat = 12
    var vPad: CGFloat = 8
    var corner: CGFloat = 10
    var onChange: (String) -> Void = { _ in }

    public init(text: Binding<String>, placeholder: String, fontSize: CGFloat, width: CGFloat? = nil, background: Color = .white, hPad: CGFloat = 12, vPad: CGFloat = 8, corner: CGFloat = 10, onChange: @escaping (String) -> Void = { _ in }) {
        self._text = text
        self.placeholder = placeholder
        self.fontSize = fontSize
        self.width = width
        self.background = background
        self.hPad = hPad
        self.vPad = vPad
        self.corner = corner
        self.onChange = onChange
    }

    public var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: fontSize))
            .padding(.vertical, vPad)
            .padding(.horizontal, hPad)
            .frame(width: width, alignment: .leading)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: corner)
                    .stroke(Color.gray.opacity(0.35), lineWidth: 1)
            )
            .cornerRadius(corner)
            .onChange(of: text, perform: onChange)
    }
}
