import SwiftUI
import FirebaseFirestore
import FirebaseStorage


// MARK: - DogDetailView（タイル一覧＋並び替え）
struct DogDetailView: View {
    let dog: DogProfile
    let onClose: () -> Void
    @EnvironmentObject var tabRouter: MainTabRouter

    @State private var items: [EvaluationWithFood] = []
    @State private var isLoading = true
    @State private var minDelayPassed = false


    // 詳細遷移（ZStackオーバーレイ）
    @State private var selectedItem: EvaluationWithFood? = nil
    @State private var showEvalDetail = false

    // Grid（SearchResultsViewと同じ3カラム）
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]


    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Text("\(dog.name)の評価記録")
                    .font(.system(size: 20, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal)

                HeaderCountRow(dog: dog, count: items.count)
                    .padding(.horizontal, 16)


                Group {
                    if isLoading || !minDelayPassed {
                        ProgressView("読み込み中…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .padding(.top, 8)
                    } else if items.isEmpty {
                        Text("まだ評価履歴がありません。")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .padding(.top, 8)
                    } else {
                        DogFoodCalendarView(items: items) { item in
                            withAnimation(.spring()) {
                                selectedItem = item
                                showEvalDetail = true
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea(edges: .bottom)
                    }
                }
            }
        .padding(.top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            // 左上の戻る
            Button { onClose() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.blue)
                    .padding(10)
                    .background(Color.white.opacity(0.8), in: Circle())
            }
            .padding(.leading, 8)
            .padding(.top, 8)

            // 新しい評価詳細オーバーレイ
            if let item = selectedItem, showEvalDetail {
                EvaluationDetailView(item: item, isPresented: $showEvalDetail)
                    .zIndex(1)
                    .transition(.move(edge: .trailing))
                    .gesture(
                        DragGesture(minimumDistance: 10, coordinateSpace: .local)
                            .onEnded { value in
                                let shouldCloseByDistance = value.translation.width > 100
                                let shouldCloseByVelocity = value.predictedEndTranslation.width > 180
                                if shouldCloseByDistance || shouldCloseByVelocity {
                                    withAnimation(.spring()) { showEvalDetail = false }
                                }
                            }
                    )
            }

            // 右下の + ボタン（検索タブへ遷移）
            Button(action: {
                withAnimation(.spring()) {
                    tabRouter.selectedTab = .search
                }
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color(red: 184/255, green: 164/255, blue: 144/255))
                    .clipShape(Circle())
                    .shadow(radius: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .onChange(of: showEvalDetail) { isPresented in
            // EvaluationDetailView が閉じられたタイミングで最新の情報を再取得
            if !isPresented {
                guard let dogID = dog.id else { return }
                resetStateForReload()
                startMinDelay()
                Task {
                    await fetchEvaluations(for: dogID)
                }
            }
        }
        .task(id: dog.id) {
            guard let dogID = dog.id else { return }
            resetStateForReload()
            startMinDelay()

            #if DEBUG
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                loadMock(); return
            }
            #endif
            await fetchEvaluations(for: dogID)
        }
    }


    // MARK: Firestore
    private func fetchEvaluations(for dogID: String) async {
        isLoading = true
        let db = Firestore.firestore()

        do {
            let snap = try await db.collection("evaluations")
                .whereField("dogID", isEqualTo: dogID)
                .getDocuments()

            let evaluations: [Evaluation] = snap.documents.compactMap { try? $0.data(as: Evaluation.self) }

            if evaluations.isEmpty {
                await MainActor.run {
                    withAnimation(.spring()) {
                        self.items = []
                        self.isLoading = false
                    }
                }
                return
            }

            var joined: [EvaluationWithFood] = []
            joined.reserveCapacity(evaluations.count)

            try await withThrowingTaskGroup(of: EvaluationWithFood?.self) { group in
                for ev in evaluations {
                    group.addTask {
                        do {
                            let doc = try await db.collection("dogfood").document(ev.dogFoodId).getDocument()
                            if let food = try? doc.data(as: DogFood.self) {
                                return EvaluationWithFood(evaluation: ev, dogFood: food)
                            } else {
                                print("⚠️ dogfood not found: \(ev.dogFoodId)")
                                return nil
                            }
                        } catch {
                            print("⚠️ dogfood fetch error (\(ev.dogFoodId)): \(error)")
                            return nil
                        }
                    }
                }
                for try await row in group { if let r = row { joined.append(r) } }
            }

            joined.sort { $0.evaluation.timestamp < $1.evaluation.timestamp }

            await MainActor.run {
                withAnimation(.spring()) {
                    self.items = joined
                    self.isLoading = false
                }
            }
        } catch {
            print("❌ Firestore取得エラー: \(error)")
            await MainActor.run {
                self.items = []
                self.isLoading = false
            }
        }
    }

    // ✅ 犬切替時の完全リセット
    private func resetStateForReload() {
        selectedItem = nil
        showEvalDetail = false
        items.removeAll()
        isLoading = true
    }

    private func startMinDelay() {
        minDelayPassed = false
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            minDelayPassed = true
        }
    }

    // MARK: Preview用
    private func loadMock() {
        let targetDogID = dog.id ?? PreviewMockData.dogs.first?.id ?? "dog_preview"
        let evs: [EvaluationWithFood] = PreviewMockData.evaluations
            .filter { $0.dogID == targetDogID }
            .compactMap { mock -> EvaluationWithFood? in
                guard let food = PreviewMockData.dogFood.first(where: { $0.id == mock.dogFoodId }) else { return nil }
                let eval = Evaluation(
                    id: UUID().uuidString,
                    dogID: mock.dogID,
                    dogName: mock.dogName,
                    breed: mock.breed,
                    dogFoodId: mock.dogFoodId,
                    userId: mock.userId,
                    overall: mock.overall,
                    dogSatisfaction: mock.dogSatisfaction,
                    ownerSatisfaction: mock.ownerSatisfaction,
                    comment: mock.comment,
                    timestamp: mock.timestamp,
                    ratings: mock.ratings
                )
                return EvaluationWithFood(evaluation: eval, dogFood: food)
            }
        self.items = evs
        self.isLoading = false
    }
}


// MARK: - Preview
#Preview("DogDetail – Grid Mock") {
    let mockDog = PreviewMockData.dogs.first!
    return DogDetailView(dog: mockDog) {
        print("🔙 戻る（プレビュー）")
    }
}

// MARK: - Calendar View（あげている期間を日にちごとに表示）
private struct DogFoodCalendarView: View {
    let items: [EvaluationWithFood]
    let onSelect: (EvaluationWithFood) -> Void

    @State private var currentMonth: Date = Date()
    @State private var dragOffset: CGFloat = 0
    @State private var storedPageWidth: CGFloat = 0   // 👈 追加
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
                    slideToPreviousMonth()     // 👈 変更
                } label: {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(monthTitle(currentMonth))
                    .font(.headline)
                Spacer()
                Button {
                    slideToNextMonth()         // 👈 変更
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
            

                // 前月・当月・翌月を用意して横に並べる
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
                            // セル本体
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
                            
                            // 2. 週×レーン単位の「ひとつづきバー」レイヤー
                            barsLayer(for: days,
                                      cellWidth: cellWidth,
                                      cellHeight: cellHeight,
                                      laneByID: laneByID,
                                      onSelect: onSelect)

                            // 罫線（縦・横）をまとめて描画（最終行の下線は描画しない）
                            Path { path in
                                // 縦線 0〜7本
                                for col in 0...7 {
                                    let x = CGFloat(col) * cellWidth
                                    path.move(to: CGPoint(x: x, y: 0))
                                    path.addLine(to: CGPoint(x: x, y: pageHeight))
                                }
                                // 横線 0〜rowCount-1 行分（最下段の横線は描かない）
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
                // 真ん中（当月）のページが画面に来るようにオフセット
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
                                // 左にスワイプ → 次の月へ（右側のページへ完全にスライド）
                                withAnimation(.easeInOut(duration: duration)) {
                                    dragOffset = -pageWidth
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                                    moveMonth(by: 1)
                                    dragOffset = 0
                                }
                            } else if translation > threshold {
                                // 右にスワイプ → 前の月へ（左側のページへ完全にスライド）
                                withAnimation(.easeInOut(duration: duration)) {
                                    dragOffset = pageWidth
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                                    moveMonth(by: -1)
                                    dragOffset = 0
                                }
                            } else {
                                // 閾値未満 → 元の位置に戻すだけ
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
        let item: EvaluationWithFood   // タップ時に渡すため

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

        // 日付 -> インデックス（0...days.count-1）マップ
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
            let key = laneKey(for: item)
            let lane = laneByID[key] ?? 0
            let ev = item.evaluation

            let rawStart = calendar.startOfDay(for: ev.feedingStartDate ?? ev.timestamp)
            let rawEndBase = ev.feedingEndDate ?? Date()
            let rawEnd = calendar.startOfDay(for: min(rawEndBase, today))

            // この月グリッドと交差しない場合はスキップ
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
    /// 開始日の早いものから見ていき、期間がかぶらない範囲で一番上のレーンを使う
    private func makeLaneAssignments(for items: [EvaluationWithFood]) -> [String: Int] {
        let today = calendar.startOfDay(for: Date())

        struct RangeInfo {
            let id: String
            let start: Date
            let end: Date
        }

        var ranges: [RangeInfo] = []

        for item in items {
            let key = laneKey(for: item)
            let ev = item.evaluation
            let start = calendar.startOfDay(for: ev.feedingStartDate ?? ev.timestamp)
            let endBase = ev.feedingEndDate ?? Date()
            let end = calendar.startOfDay(for: min(endBase, today))
            ranges.append(RangeInfo(id: key, start: start, end: end))
        }

        // 開始日の昇順に並べる
        ranges.sort { $0.start < $1.start }

        var laneEndDates: [Date] = []      // 各レーンの「最後に使われている日」
        var result: [String: Int] = [:]    // key -> lane index

        for r in ranges {
            var assignedLane: Int? = nil

            // 既存レーンのうち、開始日より前に終わっているレーンを探す
            for lane in 0..<laneEndDates.count {
                if laneEndDates[lane] < r.start {
                    assignedLane = lane
                    laneEndDates[lane] = r.end
                    break
                }
            }

            // なければ新しいレーンを一番下に追加
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
        let barTopInset: CGFloat = 16   // 日付ラベルの下に少し余白
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

        // 幅がまだ取れていない（初期状態など）のときは普通に切り替えるだけ
        guard width > 0 else {
            moveMonth(by: 1)
            return
        }

        // 右側（次の月）へフルスライド
        withAnimation(.easeInOut(duration: duration)) {
            dragOffset = -width
        }
        // アニメ完了後に月を進めて、オフセットをリセット
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

        // 左側（前の月）へフルスライド
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

        // その月の1日の曜日位置に合わせて前月分のプレースホルダーを埋める
        let firstWeekday = calendar.component(.weekday, from: firstDay) // 1 = 日
        if firstWeekday > 1 {
            for i in stride(from: firstWeekday - 2, through: 0, by: -1) {
                if let d = calendar.date(byAdding: .day, value: -i - 1, to: firstDay) {
                    days.append(d)
                }
            }
        }

        // 当月の日付
        for day in range {
            if let d = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(d)
            }
        }

        // 👇 ここを追加：最後の行が途中で終わる場合は、次の月の日で埋める
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

// 1マス分（1日）のセル
private struct DayCell: View {
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
            // 日にち（1,2,3...）
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
