import SwiftUI

// MARK: - Calendar View（あげている期間を日にちごとに表示）

struct DogFoodCalendarView: View {
    let items: [EvaluationWithFood]
    let onSelect: (EvaluationWithFood) -> Void

    @State private var currentMonth: Date = Date()
    @State private var dragOffset: CGFloat = 0
    @State private var storedPageWidth: CGFloat = 0
    private let calendar = Calendar(identifier: .gregorian)

    var currentMonthComponents: DateComponents {
        calendar.dateComponents([.year, .month], from: currentMonth)
    }

    var body: some View {
        let laneByID = makeLaneAssignments(for: items)
        VStack(spacing: 8) {
            // 月移動ヘッダー
            HStack {
                Button {
                    slideToPreviousMonth()
                } label: {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(monthTitle(currentMonth))
                    .font(.headline)
                Spacer()
                Button {
                    slideToNextMonth()
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.horizontal, 16)

            // 曜日ヘッダー（「日〜土」）固定の日本語表記
            let symbols = ["日", "月", "火", "水", "木", "金", "土"]
            HStack {
                ForEach(symbols, id: \.self) { s in
                    Text(s)
                        .font(.caption2)
                        .frame(maxWidth: .infinity)
                }
            }

            // 日にちグリッド（Googleカレンダー風・月表示）
            GeometryReader { proxy in
                let pageWidth = proxy.size.width
                let pageHeight = proxy.size.height

                let base = currentMonth
                let prev = calendar.date(byAdding: .month, value: -1, to: base) ?? base
                let next = calendar.date(byAdding: .month, value: 1, to: base) ?? base
                let months = [prev, base, next]

                HStack(spacing: 0) {
                    ForEach(months.indices, id: \.self) { index in
                        let month = months[index]
                        let days = makeDays(for: month)
                        let rowCount = max(Int(ceil(Double(days.count) / 7.0)), 1)
                        let cellHeight = pageHeight / CGFloat(rowCount)
                        let cellWidth = pageWidth / 7.0
                        let comps = calendar.dateComponents([.year, .month], from: month)

                        ZStack {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                                ForEach(days, id: \.self) { day in
                                    DayCell(date: day,
                                            items: items,
                                            calendar: calendar,
                                            currentMonthComponents: comps,
                                            cellHeight: cellHeight,
                                            laneByID: laneByID,
                                            onSelect: onSelect)
                                }
                            }

                            barsLayer(for: days,
                                      cellWidth: cellWidth,
                                      cellHeight: cellHeight,
                                      laneByID: laneByID,
                                      onSelect: onSelect)

                            Path { path in
                                for col in 0...7 {
                                    let x = CGFloat(col) * cellWidth
                                    path.move(to: CGPoint(x: x, y: 0))
                                    path.addLine(to: CGPoint(x: x, y: pageHeight))
                                }
                                for row in 0..<rowCount {
                                    let y = CGFloat(row) * cellHeight
                                    path.move(to: CGPoint(x: 0, y: y))
                                    path.addLine(to: CGPoint(x: pageWidth, y: y))
                                }
                            }
                            .stroke(Color(.systemGray4), lineWidth: 0.5)
                        }
                        .frame(width: pageWidth, height: pageHeight)
                    }
                }
                .offset(x: dragOffset - pageWidth)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation.width
                        }
                        .onEnded { value in
                            let threshold = pageWidth * 0.25
                            let translation = value.translation.width
                            let duration: Double = 0.25

                            if translation < -threshold {
                                withAnimation(.easeInOut(duration: duration)) {
                                    dragOffset = -pageWidth
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                                    moveMonth(by: 1)
                                    dragOffset = 0
                                }
                            } else if translation > threshold {
                                withAnimation(.easeInOut(duration: duration)) {
                                    dragOffset = pageWidth
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                                    moveMonth(by: -1)
                                    dragOffset = 0
                                }
                            } else {
                                withAnimation(.easeInOut(duration: duration)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
                .onAppear {
                    storedPageWidth = pageWidth
                }
                .onChange(of: pageWidth) { newValue in
                    storedPageWidth = newValue
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// カレンダー上に描画するバー（週×レーン単位）の情報
    private struct BarSegment: Identifiable {
        let id: String
        let row: Int
        let colStart: Int
        let colEnd: Int
        let lane: Int
        let color: Color
        let label: String
        let item: EvaluationWithFood

        var spanCount: Int {
            colEnd - colStart + 1
        }
    }

    /// Evaluation に保存された barColorKey からバーの色を決定
    private func barColor(for item: EvaluationWithFood) -> Color {
        let key = item.evaluation.barColorKey ?? "beige"
        let base: Color
        switch key {
        case "beige":
            base = Color(red: 184/255, green: 164/255, blue: 144/255)
        case "blue":
            base = .blue
        case "green":
            base = .green
        case "orange":
            base = .orange
        case "purple":
            base = .purple
        default:
            base = Color(red: 184/255, green: 164/255, blue: 144/255)
        }
        return base.opacity(0.5)
    }

    /// 評価の「あげた期間」を文字列化（例: 8/3〜8/10, 終了日なしなら 8/3〜）
    private func periodString(for ev: Evaluation) -> String {
        let start = ev.feedingStartDate ?? ev.timestamp
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.calendar = calendar
        f.dateFormat = "M/d"

        let startStr = f.string(from: start)

        if let end = ev.feedingEndDate {
            let endStr = f.string(from: end)
            return "\(startStr)〜\(endStr)"
        } else {
            return "\(startStr)〜"
        }
    }

    private func barLabel(for item: EvaluationWithFood) -> String {
        "\(item.dogFood.name) \(periodString(for: item.evaluation))"
    }

    /// 1つの Evaluation を、表示中の月グリッド上で「週×レーン」ごとのバーセグメントに分解する
    private func makeBarSegments(for days: [Date],
                                 laneByID: [String: Int]) -> [BarSegment] {
        guard let firstDay = days.first, let lastDay = days.last else { return [] }

        var indexByDay: [Date: Int] = [:]
        for (idx, d) in days.enumerated() {
            let key = calendar.startOfDay(for: d)
            indexByDay[key] = idx
        }

        let visibleStart = calendar.startOfDay(for: firstDay)
        let visibleEnd = calendar.startOfDay(for: lastDay)
        let today = calendar.startOfDay(for: Date())

        var result: [BarSegment] = []

        for item in items {
            let ev = item.evaluation

            if ev.feedingStartDate == nil && ev.feedingEndDate == nil {
                continue
            }

            let key = laneKey(for: item)
            let lane = laneByID[key] ?? 0

            let rawStart = calendar.startOfDay(for: ev.feedingStartDate ?? ev.timestamp)

            let rawEnd: Date
            if let endDate = ev.feedingEndDate {
                rawEnd = calendar.startOfDay(for: endDate)
            } else {
                rawEnd = max(today, rawStart)
            }

            if rawEnd < visibleStart || rawStart > visibleEnd {
                continue
            }

            let clampedStart = max(rawStart, visibleStart)
            let clampedEnd = min(rawEnd, visibleEnd)

            guard let startIndex = indexByDay[clampedStart],
                  let endIndex = indexByDay[clampedEnd] else {
                continue
            }

            var current = startIndex
            while current <= endIndex {
                let row = current / 7
                let rowEndIndex = min(endIndex, row * 7 + 6)
                let colStart = current % 7
                let colEnd = rowEndIndex % 7

                let seg = BarSegment(
                    id: "\(key)_r\(row)_c\(colStart)-\(colEnd)",
                    row: row,
                    colStart: colStart,
                    colEnd: colEnd,
                    lane: lane,
                    color: barColor(for: item),
                    label: barLabel(for: item),
                    item: item
                )
                result.append(seg)

                current = rowEndIndex + 1
            }
        }

        return result
    }

    /// 評価ごとに「バーのレーン番号」を割り当てる
    private func makeLaneAssignments(for items: [EvaluationWithFood]) -> [String: Int] {
        let today = calendar.startOfDay(for: Date())

        struct RangeInfo {
            let id: String
            let start: Date
            let end: Date
        }

        var ranges: [RangeInfo] = []

        for item in items {
            let ev = item.evaluation

            if ev.feedingStartDate == nil && ev.feedingEndDate == nil {
                continue
            }

            let key = laneKey(for: item)
            let start = calendar.startOfDay(for: ev.feedingStartDate ?? ev.timestamp)

            let end: Date
            if let endDate = ev.feedingEndDate {
                end = calendar.startOfDay(for: endDate)
            } else {
                end = max(today, start)
            }

            ranges.append(RangeInfo(id: key, start: start, end: end))
        }

        ranges.sort { $0.start < $1.start }

        var laneEndDates: [Date] = []
        var result: [String: Int] = [:]

        for r in ranges {
            var assignedLane: Int? = nil

            for lane in 0..<laneEndDates.count {
                if laneEndDates[lane] < r.start {
                    assignedLane = lane
                    laneEndDates[lane] = r.end
                    break
                }
            }

            if assignedLane == nil {
                let newLane = laneEndDates.count
                laneEndDates.append(r.end)
                assignedLane = newLane
            }

            if let lane = assignedLane {
                result[r.id] = lane
            }
        }

        return result
    }

    /// レーン割り当て用の安定キー（ドッグフードID＋評価日時）
    private func laneKey(for item: EvaluationWithFood) -> String {
        let ts = item.evaluation.timestamp.timeIntervalSince1970
        return "\(item.evaluation.dogFoodId)_\(ts)"
    }

    /// 週単位で「ひとつづき」に見えるバーを描画するレイヤー
    private func barsLayer(for days: [Date],
                           cellWidth: CGFloat,
                           cellHeight: CGFloat,
                           laneByID: [String: Int],
                           onSelect: @escaping (EvaluationWithFood) -> Void) -> some View {
        let segments = makeBarSegments(for: days, laneByID: laneByID)
        let barHeight: CGFloat = 14
        let barTopInset: CGFloat = 16
        let laneSpacing: CGFloat = 2

        return ZStack(alignment: .topLeading) {
            ForEach(segments) { seg in
                let width = CGFloat(seg.spanCount) * cellWidth
                let x = (CGFloat(seg.colStart) + CGFloat(seg.spanCount) / 2.0) * cellWidth
                let yBase = CGFloat(seg.row) * cellHeight + barTopInset
                let y = yBase + CGFloat(seg.lane) * (barHeight + laneSpacing) + barHeight / 2.0

                Button {
                    onSelect(seg.item)
                } label: {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(seg.color)
                        Text(seg.label)
                            .font(.system(size: 8, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .padding(.horizontal, 4)
                    }
                    .frame(width: width, height: barHeight)
                }
                .buttonStyle(.plain)
                .position(x: x, y: y)
            }
        }
    }

    private func slideToNextMonth() {
        let width = storedPageWidth
        let duration: Double = 0.25

        guard width > 0 else {
            moveMonth(by: 1)
            return
        }

        withAnimation(.easeInOut(duration: duration)) {
            dragOffset = -width
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            moveMonth(by: 1)
            dragOffset = 0
        }
    }

    private func slideToPreviousMonth() {
        let width = storedPageWidth
        let duration: Double = 0.25

        guard width > 0 else {
            moveMonth(by: -1)
            return
        }

        withAnimation(.easeInOut(duration: duration)) {
            dragOffset = width
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            moveMonth(by: -1)
            dragOffset = 0
        }
    }

    private func moveMonth(by offset: Int) {
        guard let newDate = calendar.date(byAdding: .month, value: offset, to: currentMonth) else { return }
        currentMonth = newDate
    }

    private func monthTitle(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.calendar = calendar
        f.dateFormat = "yyyy年 M月"
        return f.string(from: date)
    }

    private func makeDays(for month: Date) -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else {
            return []
        }

        var days: [Date] = []

        let firstWeekday = calendar.component(.weekday, from: firstDay)
        if firstWeekday > 1 {
            for i in stride(from: firstWeekday - 2, through: 0, by: -1) {
                if let d = calendar.date(byAdding: .day, value: -i - 1, to: firstDay) {
                    days.append(d)
                }
            }
        }

        for day in range {
            if let d = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(d)
            }
        }

        if let last = days.last {
            while days.count % 7 != 0 {
                if let next = calendar.date(byAdding: .day, value: 1, to: days.last ?? last) {
                    days.append(next)
                } else {
                    break
                }
            }
        }

        return days
    }
}

// MARK: - DayCell

struct DayCell: View {
    let date: Date
    let items: [EvaluationWithFood]
    let calendar: Calendar
    let currentMonthComponents: DateComponents
    let cellHeight: CGFloat
    let laneByID: [String: Int]
    let onSelect: (EvaluationWithFood) -> Void

    var body: some View {
        let dayNumber = calendar.component(.day, from: date)
        let isCurrentMonth = calendar.dateComponents([.year, .month], from: date) == currentMonthComponents

        VStack(alignment: .leading, spacing: 2) {
            Text("\(dayNumber)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(isCurrentMonth ? .primary : .secondary)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity,
               minHeight: cellHeight,
               maxHeight: cellHeight,
               alignment: .topLeading)
        .background(Color(.systemBackground))
    }
}
