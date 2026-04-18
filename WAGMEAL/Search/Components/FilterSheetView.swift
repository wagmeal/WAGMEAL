import SwiftUI
import UIKit

/// 検索画面用フィルター（成分フィルター）シート
/// - include: 「含む」(この成分が入っているフードに絞る)
/// - exclude: 「含まない」(この成分が入っていないフードに絞る)
struct FilterSheetView: View {
    @Binding var include: Set<IngredientFilter>
    @Binding var exclude: Set<IngredientFilter>

    // フード種類フィルタ
    @Binding var foodTypeFilter: FoodTypeFilter

    // 成分数値フィルタ（lowerのみBindingで保持、upperはUI state）
    @Binding var caloriesFilter: NumericFilter
    @Binding var proteinFilter: NumericFilter
    @Binding var fatFilter: NumericFilter
    @Binding var fiberFilter: NumericFilter
    @Binding var ashFilter: NumericFilter
    @Binding var moistureFilter: NumericFilter

    let selectedDog: DogProfile?
    let onUseDogAllergy: (DogProfile) -> Void

    @Environment(\.dismiss) private var dismiss

    private var beige: Color {
        Color(red: 184/255, green: 164/255, blue: 144/255)
    }

    // MARK: - Draft (apply on Done)
    @State private var draftFoodTypeFilter: FoodTypeFilter = .all

    @State private var draftCaloriesFilter: NumericFilter = .init(isEnabled: false, minValue: nil, maxValue: nil)
    @State private var draftProteinFilter: NumericFilter = .init(isEnabled: false, minValue: nil, maxValue: nil)
    @State private var draftFatFilter: NumericFilter = .init(isEnabled: false, minValue: nil, maxValue: nil)
    @State private var draftFiberFilter: NumericFilter = .init(isEnabled: false, minValue: nil, maxValue: nil)
    @State private var draftAshFilter: NumericFilter = .init(isEnabled: false, minValue: nil, maxValue: nil)
    @State private var draftMoistureFilter: NumericFilter = .init(isEnabled: false, minValue: nil, maxValue: nil)

    @State private var hasInitializedDrafts: Bool = false

    // MARK: - Nutrient input states (string-based)

    private enum NutrientKey: CaseIterable, Hashable {
        case calories, protein, fat, fiber, ash, moisture
    }

    private enum NutrientField: Hashable {
        case caloriesLower, caloriesUpper
        case proteinLower, proteinUpper
        case fatLower, fatUpper
        case fiberLower, fiberUpper
        case ashLower, ashUpper
        case moistureLower, moistureUpper
    }

    @FocusState private var focusedNutrientField: NutrientField?
    @State private var lastFocusedNutrientField: NutrientField?

    // lower text
    @State private var caloriesText: String = ""
    @State private var proteinText: String = ""
    @State private var fatText: String = ""
    @State private var fiberText: String = ""
    @State private var ashText: String = ""
    @State private var moistureText: String = ""

    // upper text
    @State private var caloriesUpperText: String = ""
    @State private var proteinUpperText: String = ""
    @State private var fatUpperText: String = ""
    @State private var fiberUpperText: String = ""
    @State private var ashUpperText: String = ""
    @State private var moistureUpperText: String = ""


    // MARK: - 1か所管理（range/step/default）

    private struct NutrientSpec: Identifiable {
        let id: NutrientKey

        let title: String
        let unit: String
        let range: ClosedRange<Double>
        let step: Double
        let keyboard: UIKeyboardType

        let lowerField: NutrientField
        let upperField: NutrientField

        /// 解除（全範囲）に戻すときの値
        let defaultLower: Double
        let defaultUpper: Double
    }

    private var nutrientSpecs: [NutrientSpec] {
        [
            .init(
                id: .calories,
                title: "代謝エネルギー", unit: "kcal/100g",
                range: 0...600, step: 5, keyboard: .numberPad,
                lowerField: .caloriesLower, upperField: .caloriesUpper,
                defaultLower: 0, defaultUpper: 600
            ),
            .init(
                id: .protein,
                title: "(粗)タンパク質", unit: "%",
                range: 0...80, step: 0.5, keyboard: .decimalPad,
                lowerField: .proteinLower, upperField: .proteinUpper,
                defaultLower: 0, defaultUpper: 80
            ),
            .init(
                id: .fat,
                title: "(粗)脂質", unit: "%",
                range: 0...40, step: 0.5, keyboard: .decimalPad,
                lowerField: .fatLower, upperField: .fatUpper,
                defaultLower: 0, defaultUpper: 40
            ),
            .init(
                id: .fiber,
                title: "(粗)繊維", unit: "%",
                range: 0...20, step: 0.5, keyboard: .decimalPad,
                lowerField: .fiberLower, upperField: .fiberUpper,
                defaultLower: 0, defaultUpper: 20
            ),
            .init(
                id: .ash,
                title: "(粗)灰分", unit: "%",
                range: 0...20, step: 0.5, keyboard: .decimalPad,
                lowerField: .ashLower, upperField: .ashUpper,
                defaultLower: 0, defaultUpper: 20
            ),
            .init(
                id: .moisture,
                title: "水分", unit: "%",
                range: 0...99, step: 1, keyboard: .decimalPad,
                lowerField: .moistureLower, upperField: .moistureUpper,
                defaultLower: 0, defaultUpper: 99
            )
        ]
    }

    // MARK: - Ingredient selection UI state

    fileprivate enum IngredientChoice: String, CaseIterable, Identifiable {
        case none
        case include
        case exclude

        var id: String { rawValue }

        var label: String {
            switch self {
            case .none: return "なし"
            case .include: return "含む"
            case .exclude: return "含まない"
            }
        }
    }

    fileprivate typealias IngredientState = IngredientChoice

    private func state(for filter: IngredientFilter) -> IngredientState {
        if include.contains(filter) { return .include }
        if exclude.contains(filter) { return .exclude }
        return .none
    }

    private func setInclude(_ filter: IngredientFilter) {
        exclude.remove(filter)
        include.insert(filter)
    }

    private func setExclude(_ filter: IngredientFilter) {
        include.remove(filter)
        exclude.insert(filter)
    }

    private func clear(_ filter: IngredientFilter) {
        include.remove(filter)
        exclude.remove(filter)
    }

    // MARK: - Helpers (normalize on commit)

    private func formatValue(_ value: Double, step: Double) -> String {
        if step >= 1 { return String(format: "%.0f", value) }
        return String(format: "%.1f", value)
    }

    private func normalize(_ raw: String, range: ClosedRange<Double>, step: Double) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed == "." { return nil }

        let replaced = trimmed.replacingOccurrences(of: "．", with: ".")
        guard let v = Double(replaced) else { return nil }

        let clamped = min(max(v, range.lowerBound), range.upperBound)
        let snapped = (clamped / step).rounded() * step
        return snapped == 0 ? 0 : snapped
    }

    // MARK: - Spec lookup / Bindings

    private func spec(for key: NutrientKey) -> NutrientSpec {
        nutrientSpecs.first(where: { $0.id == key })!
    }

    private func key(for field: NutrientField) -> NutrientKey {
        switch field {
        case .caloriesLower, .caloriesUpper: return .calories
        case .proteinLower, .proteinUpper: return .protein
        case .fatLower, .fatUpper: return .fat
        case .fiberLower, .fiberUpper: return .fiber
        case .ashLower, .ashUpper: return .ash
        case .moistureLower, .moistureUpper: return .moisture
        }
    }

    private func isUpper(field: NutrientField) -> Bool {
        switch field {
        case .caloriesUpper, .proteinUpper, .fatUpper, .fiberUpper, .ashUpper, .moistureUpper:
            return true
        default:
            return false
        }
    }

    private func filterBinding(for key: NutrientKey) -> Binding<NumericFilter> {
        switch key {
        case .calories: return $draftCaloriesFilter
        case .protein:  return $draftProteinFilter
        case .fat:      return $draftFatFilter
        case .fiber:    return $draftFiberFilter
        case .ash:      return $draftAshFilter
        case .moisture: return $draftMoistureFilter
        }
    }

    private func lowerTextBinding(for key: NutrientKey) -> Binding<String> {
        switch key {
        case .calories: return $caloriesText
        case .protein:  return $proteinText
        case .fat:      return $fatText
        case .fiber:    return $fiberText
        case .ash:      return $ashText
        case .moisture: return $moistureText
        }
    }

    private func upperTextBinding(for key: NutrientKey) -> Binding<String> {
        switch key {
        case .calories: return $caloriesUpperText
        case .protein:  return $proteinUpperText
        case .fat:      return $fatUpperText
        case .fiber:    return $fiberUpperText
        case .ash:      return $ashUpperText
        case .moisture: return $moistureUpperText
        }
    }

    // MARK: - Spec lookup / Bindings

    private func effectiveLowerValue(_ filter: NumericFilter, spec: NutrientSpec) -> Double {
        // If disabled or nil -> show default lower
        guard filter.isEnabled, let v = filter.minValue else { return spec.defaultLower }
        return min(max(v, spec.range.lowerBound), spec.range.upperBound)
    }

    private func effectiveUpperValue(_ filter: NumericFilter, spec: NutrientSpec) -> Double {
        // If disabled or nil -> show default upper
        guard filter.isEnabled, let v = filter.maxValue else { return spec.defaultUpper }
        return min(max(v, spec.range.lowerBound), spec.range.upperBound)
    }

    private func applyEnabledState(_ filter: inout NumericFilter, spec: NutrientSpec) {
        // If the user-selected range is the full range, treat it as "disabled"
        let minV = filter.minValue ?? spec.defaultLower
        let maxV = filter.maxValue ?? spec.defaultUpper

        let isFullRange = abs(minV - spec.defaultLower) < 0.0001 && abs(maxV - spec.defaultUpper) < 0.0001
        if isFullRange {
            filter.isEnabled = false
            filter.minValue = nil
            filter.maxValue = nil
        } else {
            filter.isEnabled = true
            filter.minValue = minV
            filter.maxValue = maxV
        }
    }

    // MARK: - Commit (spec参照)

    private func commitNutrient(field: NutrientField) {
        let k = key(for: field)
        let s = spec(for: k)

        var filter = filterBinding(for: k).wrappedValue
        var lowerText = lowerTextBinding(for: k).wrappedValue
        var upperText = upperTextBinding(for: k).wrappedValue

        var lowerValue = effectiveLowerValue(filter, spec: s)
        var upperValue = effectiveUpperValue(filter, spec: s)

        if isUpper(field: field) {
            // Upper commit
            if let v = normalize(upperText, range: s.range, step: s.step) {
                let floored = max(v, lowerValue) // upper >= lower
                upperValue = floored
                upperText = formatValue(floored, step: s.step)
                if upperValue < lowerValue {
                    lowerValue = upperValue
                    lowerText = formatValue(lowerValue, step: s.step)
                }
            } else if upperText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                upperText = formatValue(upperValue, step: s.step)
            }
        } else {
            // Lower commit
            if let v = normalize(lowerText, range: s.range, step: s.step) {
                let capped = min(v, upperValue) // lower <= upper
                lowerValue = capped
                lowerText = formatValue(capped, step: s.step)
                if lowerValue > upperValue {
                    upperValue = lowerValue
                    upperText = formatValue(upperValue, step: s.step)
                }
            } else if lowerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lowerText = formatValue(lowerValue, step: s.step)
            }
        }

        // Write back into filter
        filter.minValue = lowerValue
        filter.maxValue = upperValue
        applyEnabledState(&filter, spec: s)

        filterBinding(for: k).wrappedValue = filter
        lowerTextBinding(for: k).wrappedValue = lowerText
        upperTextBinding(for: k).wrappedValue = upperText
    }

    // MARK: - Sync / Reset (spec参照)

    private func syncTextFromFilters() {
        for s in nutrientSpecs {
            let key = s.id
            let filter = filterBinding(for: key).wrappedValue

            let lower = effectiveLowerValue(filter, spec: s)
            let upper = effectiveUpperValue(filter, spec: s)

            lowerTextBinding(for: key).wrappedValue = formatValue(lower, step: s.step)
            upperTextBinding(for: key).wrappedValue = formatValue(upper, step: s.step)
        }
    }

    private func resetNutrientRangesToFull() {
        for s in nutrientSpecs {
            let key = s.id
            // Full range = disabled
            filterBinding(for: key).wrappedValue = NumericFilter(isEnabled: false, minValue: nil, maxValue: nil)
            lowerTextBinding(for: key).wrappedValue = formatValue(s.defaultLower, step: s.step)
            upperTextBinding(for: key).wrappedValue = formatValue(s.defaultUpper, step: s.step)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                foodTypeSection
                nutrientSection
                ingredientFilterSection
            }
            .navigationTitle("フィルター")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            focusedNutrientField = nil
                            draftFoodTypeFilter = .all
                            include.removeAll()
                            exclude.removeAll()
                            resetNutrientRangesToFull()
                        }
                    } label: {
                        Text("全解除")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.red)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(.plain)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        // commit currently focused field into draft
                        if let field = focusedNutrientField {
                            commitNutrient(field: field)
                        }
                        focusedNutrientField = nil

                        // apply drafts to external bindings (this is when filtering should happen)
                        foodTypeFilter = draftFoodTypeFilter
                        caloriesFilter = draftCaloriesFilter
                        proteinFilter = draftProteinFilter
                        fatFilter = draftFatFilter
                        fiberFilter = draftFiberFilter
                        ashFilter = draftAshFilter
                        moistureFilter = draftMoistureFilter

                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") {
                        if let field = focusedNutrientField {
                            commitNutrient(field: field)
                        }
                        focusedNutrientField = nil
                    }
                }
            }
        }
        .onAppear {
            if !hasInitializedDrafts {
                draftFoodTypeFilter = foodTypeFilter
                draftCaloriesFilter = caloriesFilter
                draftProteinFilter = proteinFilter
                draftFatFilter = fatFilter
                draftFiberFilter = fiberFilter
                draftAshFilter = ashFilter
                draftMoistureFilter = moistureFilter
                hasInitializedDrafts = true
            }
            syncTextFromFilters()
        }
        .onChange(of: focusedNutrientField) { newValue in
            if let old = lastFocusedNutrientField, old != newValue {
                commitNutrient(field: old)
            }
            lastFocusedNutrientField = newValue
        }
    }

    // MARK: - Sections

    private var foodTypeSection: some View {
        Section(header: Text("フードの種類")) {
            HStack(spacing: 8) {
                ForEach(FoodTypeFilter.allCases) { type in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            draftFoodTypeFilter = type
                        }
                    } label: {
                        Text(type.label)
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(draftFoodTypeFilter == type ? beige.opacity(0.45) : Color(.systemGray6))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(.systemGray3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var nutrientSection: some View {
        Section(
            header: HStack {
                Text("成分値（範囲指定）")
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        focusedNutrientField = nil
                        resetNutrientRangesToFull()
                    }
                } label: {
                    Text("解除")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        ) {
            ForEach(nutrientSpecs) { s in
                nutrientRow(
                    title: s.title,
                    unit: s.unit,
                    range: s.range,
                    step: s.step,
                    filter: filterBinding(for: s.id),
                    lowerText: lowerTextBinding(for: s.id),
                    upperText: upperTextBinding(for: s.id),
                    lowerField: s.lowerField,
                    upperField: s.upperField,
                    keyboard: s.keyboard
                )
            }
        }
    }

    private func nutrientRow(
        title: String,
        unit: String,
        range: ClosedRange<Double>,
        step: Double,
        filter: Binding<NumericFilter>,
        lowerText: Binding<String>,
        upperText: Binding<String>,
        lowerField: NutrientField,
        upperField: NutrientField,
        keyboard: UIKeyboardType
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(title)【\(unit)】")
                    .font(.footnote.weight(.semibold))
                Spacer()
            }

            VStack(spacing: 4) {
                let specKey = key(for: lowerField)
                let spec = spec(for: specKey)

                RangeSlider(
                    lowerValue: Binding(
                        get: {
                            let f = filter.wrappedValue
                            return effectiveLowerValue(f, spec: spec)
                        },
                        set: { newValue in
                            var f = filter.wrappedValue
                            let currentUpper = effectiveUpperValue(f, spec: spec)
                            let capped = min(newValue, currentUpper)

                            f.minValue = capped
                            f.maxValue = currentUpper
                            applyEnabledState(&f, spec: spec)
                            filter.wrappedValue = f

                            if focusedNutrientField != lowerField && focusedNutrientField != upperField {
                                lowerText.wrappedValue = formatValue(capped, step: step)
                            }
                        }
                    ),
                    upperValue: Binding(
                        get: {
                            let f = filter.wrappedValue
                            return effectiveUpperValue(f, spec: spec)
                        },
                        set: { newValue in
                            var f = filter.wrappedValue
                            let currentLower = effectiveLowerValue(f, spec: spec)
                            let floored = max(newValue, currentLower)

                            f.minValue = currentLower
                            f.maxValue = floored
                            applyEnabledState(&f, spec: spec)
                            filter.wrappedValue = f

                            if focusedNutrientField != lowerField && focusedNutrientField != upperField {
                                upperText.wrappedValue = formatValue(floored, step: step)
                            }
                        }
                    ),
                    range: range,
                    step: step,
                    accent: beige
                )
                .frame(height: 28)

                HStack {
                    TextField("", text: lowerText)
                        .keyboardType(keyboard)
                        .multilineTextAlignment(.leading)
                        .frame(width: 35, alignment: .leading)
                        .font(.footnote)
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(.systemGray3), lineWidth: 1)
                        )
                        .focused($focusedNutrientField, equals: lowerField)

                    Spacer()

                    TextField("", text: upperText)
                        .keyboardType(keyboard)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 35, alignment: .trailing)
                        .font(.footnote)
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(.systemGray3), lineWidth: 1)
                        )
                        .focused($focusedNutrientField, equals: upperField)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var ingredientFilterSection: some View {
        Section(
            header: HStack {
                Text("成分フィルター")
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        include.removeAll()
                        exclude.removeAll()
                    }
                } label: {
                    Text("解除")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        ) {
            ForEach(IngredientFilter.allCases) { filter in
                let current = state(for: filter)
                let isOn = (current != .none)

                HStack(alignment: .center, spacing: 12) {
                    Text(filter.label)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { isOn },
                        set: { newValue in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if newValue {
                                    setInclude(filter)
                                } else {
                                    clear(filter)
                                }
                            }
                        }
                    ))
                    .labelsHidden()
                    .scaleEffect(0.9)
                    .tint(beige)

                    HStack(spacing: 0) {
                        Button {
                            setInclude(filter)
                        } label: {
                            Text("含む")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(current == .include ? beige.opacity(0.45) : Color(.systemGray6))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.systemGray3), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)

                        Button {
                            setExclude(filter)
                        } label: {
                            Text("含まない")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(current == .exclude ? beige.opacity(0.45) : Color(.systemGray6))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.systemGray3), lineWidth: 1)
                                )
                                .overlay(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color(.systemGray6))
                                        .frame(width: 1)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                    .disabled(!isOn)
                    .opacity(isOn ? 1.0 : 0.45)
                }
                .padding(.vertical, 6)
            }
        }
    }
}


// MARK: - Preview

private struct FilterSheetView_PreviewWrapper: View {
    @State private var include: Set<IngredientFilter> = [.fish]
    @State private var exclude: Set<IngredientFilter> = [.chicken, .beef]

    @State private var foodTypeFilter: FoodTypeFilter = .all
    @State private var caloriesFilter: NumericFilter = .init(isEnabled: false, minValue: nil, maxValue: nil)
    @State private var proteinFilter: NumericFilter = .init(isEnabled: false, minValue: nil, maxValue: nil)
    @State private var fatFilter: NumericFilter = .init(isEnabled: false, minValue: nil, maxValue: nil)
    @State private var fiberFilter: NumericFilter = .init(isEnabled: false, minValue: nil, maxValue: nil)
    @State private var ashFilter: NumericFilter = .init(isEnabled: false, minValue: nil, maxValue: nil)
    @State private var moistureFilter: NumericFilter = .init(isEnabled: false, minValue: nil, maxValue: nil)

    var body: some View {
        FilterSheetView(
            include: $include,
            exclude: $exclude,
            foodTypeFilter: $foodTypeFilter,
            caloriesFilter: $caloriesFilter,
            proteinFilter: $proteinFilter,
            fatFilter: $fatFilter,
            fiberFilter: $fiberFilter,
            ashFilter: $ashFilter,
            moistureFilter: $moistureFilter,
            selectedDog: nil,
            onUseDogAllergy: { _ in }
        )
    }
}

#Preview("FilterSheetView") {
    FilterSheetView_PreviewWrapper()
}
