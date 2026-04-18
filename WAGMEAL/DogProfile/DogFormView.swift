

import SwiftUI
import PhotosUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

// MARK: - Form Mode
enum DogFormMode: Equatable {
    case create
    case edit(existing: DogProfile)
}


// MARK: - Breed Presets (shared)
struct DogBreedPresets {
    static let small = [
        "イタリアン・グレーハウンド",
        "ウェスト・ハイランド・ホワイト・テリア",
        "カニンヘン・ダックスフンド",
        "カバリアプー（ミックス犬）",
        "キャバリア・キング・チャールズ・スパニエル",
        "ケアーン・テリア",
        "シーズー",
        "シルキー・テリア",
        "シルバープードル",
        "ジャック・ラッセル・テリア",
        "狆（チン）",
        "スキッパーキ",
        "スコティッシュ・テリア",
        "ダックスフンド（ミニチュア）",
        "ダンディ・ディンモント・テリア",
        "タイニー・プードル",
        "チワワ",
        "チワックス（ミックス犬）",
        "チワプー（ミックス犬）",
        "チワブル（ミックス犬）",
        "ティーカップ・プードル",
        "トイ・フォックス・テリア",
        "トイ・プードル",
        "トイ・マンチェスター・テリア",
        "日本テリア",
        "ノーフォーク・テリア",
        "ノーリッチ・テリア",
        "ハバニーズ",
        "パグ",
        "パピヨン",
        "パピプー（ミックス犬）",
        "ビション・フリーゼ",
        "ブリュッセル・グリフォン",
        "ボストン・テリア",
        "ボロニーズ",
        "ポメチワ（ミックス犬）",
        "ポメプー（ミックス犬）",
        "ポメラニアン",
        "マルチーズ",
        "マルプー（ミックス犬）",
        "マンチェスター・テリア",
        "ミニチュア・シュナウザー",
        "ミニチュア・ピンシャー",
        "ミニチュア・ブル・テリア",
        "ヨークシャー・テリア",
        "ヨープー（ミックス犬）"
    ]

    static let medium = [
        "アメリカン・コッカー・スパニエル",
        "アメリカン・スタッフォードシャー・テリア",
        "アメリカン・ブリー",
        "イングリッシュ・コッカー・スパニエル",
        "イングリッシュ・スプリンガー・スパニエル",
        "イングリッシュ・ブルドッグ",
        "ウィペット",
        "オーストラリアン・キャトル・ドッグ",
        "オーストラリアン・シェパード",
        "コーイケルホンディエ",
        "コーギー",
        "コッカプー（ミックス犬）",
        "シェットランド・シープドッグ",
        "柴犬",
        "柴プー（ミックス犬）",
        "シュナウザー（スタンダード）",
        "スタッフォードシャー・ブル・テリア",
        "ダックスフンド（スタンダード）",
        "ダルメシアン",
        "日本スピッツ",
        "バセット・ハウンド",
        "バセンジー",
        "ビーグル",
        "フレンチ・ブルドッグ",
        "ブル・テリア",
        "ブルドッグ",
        "ボーダー・コリー",
        "ミニチュア・アメリカン・シェパード"
    ]

    static let large = [
        "アイリッシュ・ウルフハウンド",
        "アイリッシュ・セッター",
        "秋田犬",
        "アフガン・ハウンド",
        "アラスカン・マラミュート",
        "エアデール・テリア",
        "オーストラリアン・ラブラドゥードル",
        "オールド・イングリッシュ・シープドッグ",
        "グレート・デーン",
        "グレート・ピレニーズ",
        "グレーハウンド",
        "ゴールデン・レトリーバー",
        "ゴールデンドゥードル（ミックス犬）",
        "サモエド",
        "サルーキ",
        "シベリアン・ハスキー",
        "シュナウザー（ジャイアント）",
        "スタンダード・プードル",
        "セント・バーナード",
        "ドーベルマン",
        "ナポリタン・マスティフ",
        "ニューファンドランド",
        "バーニーズ・マウンテン・ドッグ",
        "フラットコーテッド・レトリーバー",
        "ラブラドゥードル",
        "ラブラドール・レトリーバー",
        "ラフ・コリー",
        "レオンベルガー",
        "ロットワイラー",
        "ワイマラナー"
    ]
}

// MARK: - Allergy Presets (per dog)
struct DogAllergyPresets {
    static let options: [String] = [
        "鶏肉",
        "牛肉",
        "豚肉",
        "羊/ラム",
        "魚",
        "卵",
        "乳製品",
        "小麦",
        "トウモロコシ",
        "大豆"
    ]
}

// MARK: - Shared Form State
final class DogFormState: ObservableObject {
    // Inputs
    @Published var name: String = ""
    @Published var gender: String = "男の子"
    @Published var breed: String = ""
    @Published var size: String = ""
    @Published var birthDate: Date = Date()

    // Wheel picker selection (breed id). "__other__" means user will input manually.
    @Published var selectedBreedID: String = ""

    // Per-dog allergy selection (labels from DogAllergyPresets.options)
    @Published var allergies: Set<String> = []

    // "Other" input
    @Published var otherBreedInput: String = ""
    @Published var showOtherInputFieldForSize: String? = nil

    // Image picking / cropping
    @Published var pickedItem: PhotosPickerItem?
    @Published var pickedImage: UIImage?
    @Published var cropPayload: ImageCropPayload?
    @Published var removeImage = false

    // Working state
    @Published var isWorking = false
    @Published var errorMessage: String?

    // Initialization from mode
    init(mode: DogFormMode) {
        if case .edit(let dog) = mode {
            self.name = dog.name
            self.gender = dog.gender
            self.breed = dog.breed
            self.size = dog.sizeCategory
            self.birthDate = dog.birthDate

            // Show "その他" text field if the existing breed isn't in presets for its size
            let inSmall = DogBreedPresets.small.contains(dog.breed)
            let inMedium = DogBreedPresets.medium.contains(dog.breed)
            let inLarge = DogBreedPresets.large.contains(dog.breed)
            let exists: Bool = {
                switch dog.sizeCategory {
                case "小型犬": return inSmall
                case "中型犬": return inMedium
                case "大型犬": return inLarge
                default: return false
                }
            }()
            if !exists { showOtherInputFieldForSize = dog.sizeCategory; otherBreedInput = dog.breed }

            // Wheel selection
            self.selectedBreedID = exists ? dog.breed : "__other__"

            // 既存DogProfileのアレルギーフラグからフォームの選択を復元
            if dog.allergicChicken ?? false { allergies.insert("鶏肉") }
            if dog.allergicBeef ?? false { allergies.insert("牛肉") }
            if dog.allergicPork ?? false { allergies.insert("豚肉") }
            if dog.allergicLamb ?? false { allergies.insert("羊/ラム") }
            if dog.allergicFish ?? false { allergies.insert("魚") }
            if dog.allergicEgg ?? false { allergies.insert("卵") }
            if dog.allergicDairy ?? false { allergies.insert("乳製品") }
            if dog.allergicWheat ?? false { allergies.insert("小麦") }
            if dog.allergicCorn ?? false { allergies.insert("トウモロコシ") }
            if dog.allergicSoy ?? false { allergies.insert("大豆") }
        }
        // For create mode, set default selection
        switch mode {
        case .create:
            self.selectedBreedID = ""
        case .edit:
            break
        }
    }
}

// MARK: - Shared View
struct DogFormView: View {
    let mode: DogFormMode
    @ObservedObject var dogVM: DogProfileViewModel

    // For create flow, you used this to store the current selection in MyDogView
    var selectedDogID: Binding<String?>? = nil

    @Environment(\.dismiss) private var dismiss
    @StateObject private var form: DogFormState

    // Styling knobs (kept to match your current UI)
    @State private var breedChipFontSize: CGFloat = 15
    @State private var chipHSpacing: CGFloat = 0
    @State private var chipVSpacing: CGFloat = 10
    @State private var chipHPadding: CGFloat = 12
    @State private var chipVPadding: CGFloat = 8
    @State private var otherInputWidth: CGFloat = 250

    @State private var showDeletePhotoAlert = false
    @State private var showPhotoPicker = false
    @State private var showBreedPickerSheet = false

    // MARK: - Breed Wheel Picker Helpers
    private struct BreedOption: Identifiable {
        let id: String
        let breed: String
        let sizeCategory: String
    }

    /// 表示順を完全に手動管理する犬種マスター（この順でリールに表示される）
    /// ※ 必ずDogBreedPresetsの全犬種を含めてください（含まれていないとリールに出ません）
    private let orderedBreeds: [(breed: String, size: String)] = [
        ("アイリッシュ・ウルフハウンド", "大型犬"),
        ("アイリッシュ・セッター", "大型犬"),
        ("秋田犬", "大型犬"),
        ("アフガン・ハウンド", "大型犬"),
        ("アメリカン・コッカー・スパニエル", "中型犬"),
        ("アメリカン・スタッフォードシャー・テリア", "中型犬"),
        ("アメリカン・ブリー", "中型犬"),
        ("アラスカン・マラミュート", "大型犬"),
        ("イタリアン・グレーハウンド", "小型犬"),
        ("イングリッシュ・コッカー・スパニエル", "中型犬"),
        ("イングリッシュ・スプリンガー・スパニエル", "中型犬"),
        ("イングリッシュ・ブルドッグ", "中型犬"),
        ("ウィペット", "中型犬"),
        ("ウェスト・ハイランド・ホワイト・テリア", "小型犬"),
        ("エアデール・テリア", "大型犬"),
        ("オーストラリアン・キャトル・ドッグ", "中型犬"),
        ("オーストラリアン・シェパード", "中型犬"),
        ("オーストラリアン・ラブラドゥードル", "大型犬"),
        ("オールド・イングリッシュ・シープドッグ", "大型犬"),
        ("カニンヘン・ダックスフンド", "小型犬"),
        ("カバリアプー（ミックス犬）", "小型犬"),
        ("キャバリア・キング・チャールズ・スパニエル", "小型犬"),
        ("グレート・デーン", "大型犬"),
        ("グレート・ピレニーズ", "大型犬"),
        ("グレーハウンド", "大型犬"),
        ("ケアーン・テリア", "小型犬"),
        ("コーイケルホンディエ", "中型犬"),
        ("コーギー", "中型犬"),
        ("コッカプー（ミックス犬）", "中型犬"),
        ("ゴールデン・レトリーバー", "大型犬"),
        ("ゴールデンドゥードル（ミックス犬）", "大型犬"),
        ("サモエド", "大型犬"),
        ("サルーキ", "大型犬"),
        ("シーズー", "小型犬"),
        ("シェットランド・シープドッグ", "中型犬"),
        ("柴犬", "中型犬"),
        ("柴プー（ミックス犬）", "中型犬"),
        ("シベリアン・ハスキー", "大型犬"),
        ("シルキー・テリア", "小型犬"),
        ("シルバープードル", "小型犬"),
        ("ジャック・ラッセル・テリア", "小型犬"),
        ("シュナウザー（ジャイアント）", "大型犬"),
        ("シュナウザー（スタンダード）", "中型犬"),
        ("スキッパーキ", "小型犬"),
        ("スコティッシュ・テリア", "小型犬"),
        ("スタッフォードシャー・ブル・テリア", "中型犬"),
        ("スタンダード・プードル", "大型犬"),
        ("セント・バーナード", "大型犬"),
        ("ダックスフンド（スタンダード）", "中型犬"),
        ("ダックスフンド（ミニチュア）", "小型犬"),
        ("ダンディ・ディンモント・テリア", "小型犬"),
        ("ダルメシアン", "中型犬"),
        ("タイニー・プードル", "小型犬"),
        ("チワワ", "小型犬"),
        ("チワックス（ミックス犬）", "小型犬"),
        ("チワプー（ミックス犬）", "小型犬"),
        ("チワブル（ミックス犬）", "小型犬"),
        ("狆（チン）", "小型犬"),
        ("ティーカップ・プードル", "小型犬"),
        ("トイ・フォックス・テリア", "小型犬"),
        ("トイ・プードル", "小型犬"),
        ("トイ・マンチェスター・テリア", "小型犬"),
        ("ドーベルマン", "大型犬"),
        ("ナポリタン・マスティフ", "大型犬"),
        ("ニューファンドランド", "大型犬"),
        ("日本スピッツ", "中型犬"),
        ("日本テリア", "小型犬"),
        ("ノーフォーク・テリア", "小型犬"),
        ("ノーリッチ・テリア", "小型犬"),
        ("ハバニーズ", "小型犬"),
        ("パグ", "小型犬"),
        ("パピヨン", "小型犬"),
        ("パピプー（ミックス犬）", "小型犬"),
        ("バーニーズ・マウンテン・ドッグ", "大型犬"),
        ("バセット・ハウンド", "中型犬"),
        ("バセンジー", "中型犬"),
        ("ビーグル", "中型犬"),
        ("ビション・フリーゼ", "小型犬"),
        ("フラットコーテッド・レトリーバー", "大型犬"),
        ("フレンチ・ブルドッグ", "中型犬"),
        ("ブリュッセル・グリフォン", "小型犬"),
        ("ブル・テリア", "中型犬"),
        ("ブルドッグ", "中型犬"),
        ("ボーダー・コリー", "中型犬"),
        ("ボストン・テリア", "小型犬"),
        ("ボロニーズ", "小型犬"),
        ("ポメチワ（ミックス犬）", "小型犬"),
        ("ポメプー（ミックス犬）", "小型犬"),
        ("ポメラニアン", "小型犬"),
        ("マルチーズ", "小型犬"),
        ("マルプー（ミックス犬）", "小型犬"),
        ("マンチェスター・テリア", "小型犬"),
        ("ミニチュア・アメリカン・シェパード", "中型犬"),
        ("ミニチュア・シュナウザー", "小型犬"),
        ("ミニチュア・ピンシャー", "小型犬"),
        ("ミニチュア・ブル・テリア", "小型犬"),
        ("ヨークシャー・テリア", "小型犬"),
        ("ヨープー（ミックス犬）", "小型犬"),
        ("ラブラドゥードル", "大型犬"),
        ("ラブラドール・レトリーバー", "大型犬"),
        ("ラフ・コリー", "大型犬"),
        ("レオンベルガー", "大型犬"),
        ("ロットワイラー", "大型犬"),
        ("ワイマラナー", "大型犬")
    ]

    private var breedOptions: [BreedOption] {
        let ordered = orderedBreeds.map {
            BreedOption(id: $0.breed, breed: $0.breed, sizeCategory: $0.size)
        }
        return ordered + [BreedOption(id: "__other__", breed: "手動入力", sizeCategory: "")]
    }

    private func sizeCategory(forBreedID id: String) -> String? {
        breedOptions.first(where: { $0.id == id })?.sizeCategory
    }

    // MARK: - Breed Picker Selection Handler
    private func applyBreedSelection(_ newValue: String) {
        if newValue == "__other__" {
            // 手入力モード
            if form.size.isEmpty { form.size = "小型犬" }
            // 手動入力では、この画面で otherBreedInput を入力して form.breed に反映する
            form.showOtherInputFieldForSize = form.size
            form.breed = form.otherBreedInput.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let sizeCat = sizeCategory(forBreedID: newValue) {
            form.size = sizeCat
            form.breed = newValue
            form.showOtherInputFieldForSize = nil
            form.otherBreedInput = ""
        }
    }

    init(mode: DogFormMode, dogVM: DogProfileViewModel, selectedDogID: Binding<String?>? = nil) {
        self.mode = mode
        self.dogVM = dogVM
        self.selectedDogID = selectedDogID
        _form = StateObject(wrappedValue: DogFormState(mode: mode))
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: プロフィール画像
                Section(header: Text("プロフィール画像")) {
                    HStack(spacing: 16) {
                        Group {
                            if let ui = form.pickedImage {
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFill()
                            } else if case .edit(let dog) = mode, let path = dog.imagePath, !path.isEmpty, !form.removeImage {
                                StorageImageView(imagePath: path, width: 72, height: 72, contentMode: .fill, cornerRadius: 36)
                            } else {
                                Image(placeholderAsset(for: effectiveSize))
                                    .resizable()
                                    .scaledToFit()
                                    .padding(15)
                                    .background(Color(UIColor.systemGray5))
                            }
                        }
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 100) {
                                Text(photoButtonTitle)
                                    .foregroundColor(.blue)
                                    .onTapGesture {
                                        showPhotoPicker = true
                                    }
                                    .photosPicker(
                                        isPresented: $showPhotoPicker,
                                        selection: $form.pickedItem,
                                        matching: .images,
                                        photoLibrary: .shared()
                                    )
                                    .onChange(of: form.pickedItem) { newItem in
                                        guard let newItem else { return }
                                        Task {
                                            if let data = try? await newItem.loadTransferable(type: Data.self),
                                               let img = UIImage(data: data) {
                                                await MainActor.run { form.cropPayload = ImageCropPayload(image: img) }
                                            }
                                        }
                                    }
                                
                                if shouldShowDeletePhotoButton {
                                    Text("削除")
                                        .foregroundColor(.red)
                                        .onTapGesture {
                                            showDeletePhotoAlert = true
                                        }
                                }
                            }
                        }
                    }
                }

                // MARK: 基本情報
                Section(header: Text("名前")) {
                    TextField("わんちゃんの名前", text: $form.name)
                }
                Section(header: Text("性別")) {
                    Picker("性別", selection: $form.gender) {
                        Text("男の子").tag("男の子")
                        Text("女の子").tag("女の子")
                    }
                    .pickerStyle(.segmented)
                }
                Section(header: Text("誕生日")) {
                    DatePicker("誕生日を選択", selection: $form.birthDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                }

                // MARK: 犬種（タップでリール表示）
                Section(header: Text("犬種")) {
                    Button {
                        showBreedPickerSheet = true
                    } label: {
                        HStack {
                            Text("犬種")
                                .foregroundColor(.primary)
                                .fixedSize()
                            Spacer()
                            Text(form.selectedBreedID.isEmpty ? "選択してください" : (form.selectedBreedID == "__other__" ? (form.otherBreedInput.isEmpty ? "手動入力" : form.otherBreedInput) : form.selectedBreedID))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.trailing)
                                .fixedSize(horizontal: false, vertical: true)
                                .layoutPriority(1)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .buttonStyle(.plain)

                    if form.selectedBreedID == "__other__" {
                        // 手動入力：この画面（Form）上でサイズと犬種を入力
                        Picker("サイズ", selection: $form.size) {
                            Text("小型犬").tag("小型犬")
                            Text("中型犬").tag("中型犬")
                            Text("大型犬").tag("大型犬")
                        }
                        .pickerStyle(.segmented)

                        TextField("犬種を入力", text: $form.otherBreedInput)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: form.otherBreedInput) { newValue in
                                form.breed = newValue
                            }
                    } else {
                        // サイズは裏で保持（ユーザーには参考表示として出す）
                        if !form.size.isEmpty {
                            Text("サイズ：\(form.size)")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // MARK: アレルギー（わんちゃんごと）
                Section(header: Text("アレルギー")) {
                    allergyPickerSection()
                }

                // MARK: 保存/追加ボタン
                Button(action: onPrimaryButton) {
                    if form.isWorking {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text(primaryButtonTitle).frame(maxWidth: .infinity)
                    }
                }
                .disabled(form.isWorking || form.name.isEmpty || form.breed.isEmpty)
                .foregroundColor(.white)
                .padding()
                .background((form.isWorking || form.name.isEmpty || form.breed.isEmpty) ? Color.gray : Color(red: 184/255, green: 164/255, blue: 144/255))
                .cornerRadius(10)

                if let msg = form.errorMessage { Text(msg).foregroundColor(.red).font(.footnote) }
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
        // Cropper
        .fullScreenCover(item: $form.cropPayload) { payload in
            CropAvatarView(
                original: payload.image,
                onCancel: { form.cropPayload = nil },
                onDone: { cropped in
                    form.pickedImage = cropped
                    form.removeImage = false
                    form.cropPayload = nil
                }
            )
        }
        .alert("写真を削除しますか？", isPresented: $showDeletePhotoAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("はい", role: .destructive) {
                handleDeletePhotoConfirmed()
            }
        }
            .sheet(isPresented: $showBreedPickerSheet) {
                NavigationStack {
                    VStack(spacing: 0) {
                        Picker("犬種", selection: $form.selectedBreedID) {
                            ForEach(breedOptions) { opt in
                                Text(opt.breed).tag(opt.id)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 260)
                        .clipped()
                        .onChange(of: form.selectedBreedID) { newValue in
                            applyBreedSelection(newValue)
                        }
                    }
                    .navigationTitle("犬種を選択")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("キャンセル") {
                                // ここでは選択を戻さず閉じる（必要なら後で一時保存方式に変更可能）
                                showBreedPickerSheet = false
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("完了") {
                                // 手動入力の場合でも、入力は Form 側で行うため常に閉じてOK
                                showBreedPickerSheet = false
                            }
                        }
                    }
                }
                .presentationDetents([.height(340)])
            }
    }

    // MARK: - Derived
    private var navigationTitle: String {
        switch mode { case .create: return "新規追加"; case .edit: return "編集" }
    }
    private var primaryButtonTitle: String { mode == .create ? "追加" : "保存" }
    private var photoButtonTitle: String { mode == .create ? "写真を選択" : "写真を変更" }

    private var effectiveSize: String {
        switch mode {
        case .create: return form.size
        case .edit(let dog): return form.size.isEmpty ? dog.sizeCategory : form.size
        }
    }

    // MARK: - Derived
    private var shouldShowDeletePhotoButton: Bool {
        if form.pickedImage != nil {
            return true
        }
        if case .edit(let dog) = mode,
           let path = dog.imagePath,
           !path.isEmpty,
           !form.removeImage {
            return true
        }
        return false
    }

    // MARK: - Actions
    private func handleDeletePhotoConfirmed() {
        // 1. 直近で選択した写真がある場合は、その選択を取り消す
        if form.pickedImage != nil {
            form.pickedImage = nil
            form.pickedItem = nil
            form.removeImage = false
            return
        }

        // 2. Editモードで既存画像のみある場合は、削除フラグを立てて画像を消す
        switch mode {
        case .edit:
            form.removeImage = true
        case .create:
            break
        }
    }

    private func onPrimaryButton() {
        switch mode {
        case .create: createDog()
        case .edit(let dog): updateDog(existing: dog)
        }
    }

    private func createDog() {
        guard let userID = Auth.auth().currentUser?.uid else { form.errorMessage = "ログインユーザーが見つかりません"; return }
        form.isWorking = true; form.errorMessage = nil

        let db = Firestore.firestore()
        let docRef = db.collection("users").document(userID).collection("dogs").document()

        var newDog = DogProfile(
            id: docRef.documentID,
            name: form.name,
            birthDate: form.birthDate,
            gender: form.gender,
            breed: form.breed,
            sizeCategory: form.size,
            createdAt: Date(),
            imagePath: nil
        )

        // フォームの選択内容からDogProfileのアレルギーフラグを設定
        newDog.allergicChicken = form.allergies.contains("鶏肉")
        newDog.allergicBeef    = form.allergies.contains("牛肉")
        newDog.allergicPork    = form.allergies.contains("豚肉")
        newDog.allergicLamb    = form.allergies.contains("羊/ラム")
        newDog.allergicFish    = form.allergies.contains("魚")
        newDog.allergicEgg     = form.allergies.contains("卵")
        newDog.allergicDairy   = form.allergies.contains("乳製品")
        newDog.allergicWheat   = form.allergies.contains("小麦")
        newDog.allergicCorn    = form.allergies.contains("トウモロコシ")
        newDog.allergicSoy     = form.allergies.contains("大豆")

        do {
            try docRef.setData(from: newDog) { err in
                if let err { form.isWorking = false; form.errorMessage = "Firestore登録に失敗: \(err.localizedDescription)"; return }

                guard let image = form.pickedImage else { finishCreateSuccess(docRef: docRef, newDog: newDog) ; return }

                let timestamp = Int(Date().timeIntervalSince1970)
                let path = "users/\(userID)/dogs/\(docRef.documentID)/\(timestamp).jpg"
                upload(image: image, to: path) { result in
                    switch result {
                    case .success:
                        docRef.updateData(["imagePath": path]) { _ in
                            newDog.imagePath = path
                            finishCreateSuccess(docRef: docRef, newDog: newDog)
                        }

                    case .failure(let e):
                        // 🔴 この登録で作成したドキュメントを削除してロールバック
                        docRef.delete { _ in
                            DispatchQueue.main.async {
                                form.isWorking = false
                                form.errorMessage = "画像アップロードに失敗しました。もう一度お試しください。\n\(e.localizedDescription)"
                            }
                        }
                    }
                }
            }
        } catch {
            form.isWorking = false; form.errorMessage = "Firestore書き込み失敗: \(error.localizedDescription)"
        }
    }

    private func finishCreateSuccess(docRef: DocumentReference, newDog: DogProfile) {
        DispatchQueue.main.async {
            // Optional: select the newly created dog id
            selectedDogID?.wrappedValue = newDog.id

            form.isWorking = false
            dismiss()
            dogVM.fetchDogs()
        }
    }

    private func updateDog(existing dog: DogProfile) {
        guard let userID = Auth.auth().currentUser?.uid else { form.errorMessage = "ログインユーザーが見つかりません"; return }
        guard let dogID = dog.id else { form.errorMessage = "編集対象のIDが不明です"; return }

        form.isWorking = true; form.errorMessage = nil

        var edited = dog
        edited.name = form.name
        edited.gender = form.gender
        edited.breed = form.breed
        edited.sizeCategory = form.size
        edited.birthDate = form.birthDate

        // フォームの選択内容からアレルギーフラグを更新
        edited.allergicChicken = form.allergies.contains("鶏肉")
        edited.allergicBeef    = form.allergies.contains("牛肉")
        edited.allergicPork    = form.allergies.contains("豚肉")
        edited.allergicLamb    = form.allergies.contains("羊/ラム")
        edited.allergicFish    = form.allergies.contains("魚")
        edited.allergicEgg     = form.allergies.contains("卵")
        edited.allergicDairy   = form.allergies.contains("乳製品")
        edited.allergicWheat   = form.allergies.contains("小麦")
        edited.allergicCorn    = form.allergies.contains("トウモロコシ")
        edited.allergicSoy     = form.allergies.contains("大豆")

        let currentPath = dog.imagePath

        // Deletion case (no new image)
        if form.removeImage && form.pickedImage == nil {
            if let existingPath = currentPath, !existingPath.isEmpty {
                Storage.storage().reference(withPath: existingPath).delete(completion: nil)
            }
            edited.imagePath = nil
            dogVM.updateDog(edited) { err in
                form.isWorking = false
                if let err {
                    form.errorMessage = "更新に失敗: \(err.localizedDescription)"
                } else {
                    dogVM.fetchDogs()
                    dismiss()
                }
            }
            return
        }

        // New/overwritten image
        if let image = form.pickedImage {
            // ユーザーIDとdogIDに基づくタイムスタンプ付きファイル名で保存
            let timestamp = Int(Date().timeIntervalSince1970)
            let newPath = "users/\(userID)/dogs/\(dogID)/\(timestamp).jpg"
            
            // 古い画像があれば削除（パスが変わっている場合）
            if let existingPath = currentPath, !existingPath.isEmpty, existingPath != newPath {
                Storage.storage().reference(withPath: existingPath).delete(completion: nil)
            }
            
            upload(image: image, to: newPath) { result in
                switch result {
                case .success:
                    // ローカルモデルにも新しいパスを反映
                    edited.imagePath = newPath
                    
                    // Firestore / ViewModel の imagePath を更新
                    dogVM.updateDogImagePath(dogID: dogID, newPath: newPath) { err in
                        if let err {
                            form.isWorking = false
                            form.errorMessage = "画像パスの更新に失敗: \(err.localizedDescription)"
                            return
                        }
                        
                        // 残りのフィールドを更新
                        dogVM.updateDog(edited) { err in
                            form.isWorking = false
                            if let err {
                                form.errorMessage = "更新に失敗: \(err.localizedDescription)"
                            } else {
                                dogVM.fetchDogs()
                                dismiss()
                            }
                        }
                    }
                case .failure(let e):
                    form.isWorking = false
                    form.errorMessage = "画像アップロードに失敗: \(e.localizedDescription)"
                }
            }
        } else {
            // Text-only update
            edited.imagePath = dog.imagePath
            dogVM.updateDog(edited) { err in
                form.isWorking = false
                if let err {
                    form.errorMessage = "更新に失敗: \(err.localizedDescription)"
                } else {
                    dogVM.fetchDogs()
                    dismiss()
                }
            }
        }
    }

    private func upload(image: UIImage, to path: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let ref = Storage.storage().reference(withPath: path)
        let data = image.jpegData(compressionQuality: 0.85) ?? image.pngData()
        guard let data else { completion(.failure(NSError(domain: "encode", code: -1, userInfo: [NSLocalizedDescriptionKey: "画像のエンコードに失敗"]))); return }
        ref.putData(data, metadata: nil) { _, error in
            if let error { completion(.failure(error)) } else { completion(.success(())) }
        }
    }

    // MARK: - Subviews
    private func breedPickerSection(title: String, breeds: [String], size: String, iconName: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(iconName).resizable().frame(width: 24, height: 24)
                Text(title).font(.headline)
            }
            FlowLayout(hSpacing: chipHSpacing, vSpacing: chipVSpacing) {
                ForEach(breeds, id: \.self) { option in
                    BreedChip(
                        label: option,
                        isSelected: (form.breed == option && form.size == size),
                        fontSize: breedChipFontSize,
                        onTap: {
                            if form.breed == option && form.size == size {
                                form.breed = ""; form.size = ""
                            } else {
                                form.breed = option; form.size = size; form.showOtherInputFieldForSize = nil
                            }
                        },
                        hPad: chipHPadding,
                        vPad: chipVPadding
                    )
                }
                Color.clear.frame(width: 0, height: 0).flowRowBreak()
                BreedChip(
                    label: "その他",
                    isSelected: form.showOtherInputFieldForSize == size,
                    fontSize: breedChipFontSize,
                    onTap: {
                        if form.showOtherInputFieldForSize == size {
                            form.showOtherInputFieldForSize = nil
                            if form.size == size && !breeds.contains(form.breed) {
                                form.breed = ""; form.size = ""
                            }
                        } else {
                            form.showOtherInputFieldForSize = size
                            form.size = size
                            form.breed = form.otherBreedInput.isEmpty ? "" : form.otherBreedInput
                        }
                    },
                    hPad: chipHPadding,
                    vPad: chipVPadding
                )
                if form.showOtherInputFieldForSize == size {
                    TextFieldChip(
                        text: $form.otherBreedInput,
                        placeholder: "犬種を入力",
                        fontSize: breedChipFontSize,
                        width: otherInputWidth,
                        background: .white
                    ) { newValue in
                        if form.showOtherInputFieldForSize == size { form.breed = newValue; form.size = size }
                    }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }

    private func allergyPickerSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowLayout(hSpacing: chipHSpacing, vSpacing: chipVSpacing) {
                ForEach(DogAllergyPresets.options, id: \.self) { option in
                    BreedChip(
                        label: option,
                        isSelected: form.allergies.contains(option),
                        fontSize: breedChipFontSize,
                        onTap: {
                            if form.allergies.contains(option) {
                                form.allergies.remove(option)
                            } else {
                                form.allergies.insert(option)
                            }
                        },
                        hPad: chipHPadding,
                        vPad: chipVPadding
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            //Text("食物アレルギーがある場合は当てはまるものを選択してください")
              //  .font(.subheadline)
                //.foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func placeholderAsset(for sizeCategory: String) -> String {
        if sizeCategory.contains("小") { return "smalldog" }
        if sizeCategory.contains("中") { return "middledog" }
        if sizeCategory.contains("大") { return "bigdog" }
        return "smalldog"
    }
}

// MARK: - Wrappers
struct NewDogView: View { // replacement for DogManagementView
    @Binding var selectedDogID: String?
    @ObservedObject var dogVM: DogProfileViewModel
    var body: some View {
        DogFormView(mode: .create, dogVM: dogVM, selectedDogID: $selectedDogID)
    }
}

struct EditDogView: View { // replacement for DogEditView
    let dog: DogProfile
    @EnvironmentObject var dogVM: DogProfileViewModel
    var body: some View {
        DogFormView(mode: .edit(existing: dog), dogVM: dogVM)
    }
}

// MARK: - Previews
#Preview("Create") {
    struct Wrapper: View {
        @State private var selected: String? = nil
        var body: some View {
            let vm = DogProfileViewModel(mockDogs: [])
            NewDogView(selectedDogID: $selected, dogVM: vm)
        }
    }
    return Wrapper()
}

#Preview("Edit") {
    let mockDogs = PreviewMockData.dogs
    let vm = DogProfileViewModel(mockDogs: mockDogs)
    return EditDogView(dog: mockDogs.first!)
        .environmentObject(vm)
}
