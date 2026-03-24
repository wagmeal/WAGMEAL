

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
    static let small = ["チワワ", "トイプードル", "マルチーズ", "ヨークシャーテリア", "ポメラニアン", "ミニチュアダックスフンド"]
    static let medium = ["柴犬", "ビーグル", "フレンチブルドッグ", "コーギー", "ボーダーコリー"]
    static let large = ["ラブラドール", "ゴールデンレトリバー", "スタンダードプードル", "バーニーズ", "グレートピレニーズ"]
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
                            } else if case .edit(let dog) = mode, let path = dog.imagePath, !path.isEmpty {
                                StorageImageView(imagePath: path, width: 72, height: 72, contentMode: .fill, cornerRadius: 36)
                            } else {
                                Image(placeholderAsset(for: effectiveSize))
                                    .resizable()
                                    .scaledToFit()
                                    .padding(20)
                                    .background(Color(UIColor.systemGray5))
                            }
                        }
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 8) {
                            PhotosPicker(selection: $form.pickedItem, matching: .images, photoLibrary: .shared()) {
                                Label(photoButtonTitle, systemImage: "photo")
                            }
                            .onChange(of: form.pickedItem) { newItem in
                                guard let newItem else { return }
                                Task {
                                    if let data = try? await newItem.loadTransferable(type: Data.self),
                                       let img = UIImage(data: data) {
                                        await MainActor.run { form.cropPayload = ImageCropPayload(image: img) }
                                    }
                                }
                            }

                            if case .edit(let dog) = mode, (dog.imagePath != nil || form.pickedImage != nil) {
                                Button(role: .destructive) {
                                    form.removeImage.toggle()
                                    if form.removeImage { form.pickedImage = nil }
                                } label: {
                                    Text(form.removeImage ? "画像を削除（取り消す）" : "画像を削除")
                                }
                                .font(.caption)
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

                // MARK: 犬種（サイズ別）
                Section(header: Text("犬種（サイズ別）")) {
                    breedPickerSection(title: "小型犬", breeds: DogBreedPresets.small, size: "小型犬", iconName: "smalldog")
                    breedPickerSection(title: "中型犬", breeds: DogBreedPresets.medium, size: "中型犬", iconName: "middledog")
                    breedPickerSection(title: "大型犬", breeds: DogBreedPresets.large, size: "大型犬", iconName: "bigdog")
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

    // MARK: - Actions
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

                let path = "users/\(userID)/dogs/\(docRef.documentID).jpg"
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

        let path = "users/\(userID)/dogs/\(dogID).jpg"
        let db = Firestore.firestore()
        let docRef = db.collection("users").document(userID).collection("dogs").document(dogID)

        // Deletion case (no new image)
        if form.removeImage && form.pickedImage == nil {
            if let _ = dog.imagePath {
                Storage.storage().reference(withPath: path).delete(completion: nil)
            }
            edited.imagePath = nil
            dogVM.updateDog(edited) { err in
                form.isWorking = false
                if let err { form.errorMessage = "更新に失敗: \(err.localizedDescription)" }
                else { dismiss() }
            }
            return
        }

        // New/overwritten image
        if let image = form.pickedImage {
            upload(image: image, to: path) { result in
                switch result {
                case .success:
                    docRef.updateData(["imagePath": path]) { _ in
                        edited.imagePath = path
                        dogVM.updateDog(edited) { err in
                            form.isWorking = false
                            if let err { form.errorMessage = "更新に失敗: \(err.localizedDescription)" }
                            else { dismiss() }
                        }
                    }
                case .failure(let e):
                    form.isWorking = false; form.errorMessage = "画像アップロードに失敗: \(e.localizedDescription)"
                }
            }
        } else {
            // Text-only update
            edited.imagePath = dog.imagePath
            dogVM.updateDog(edited) { err in
                form.isWorking = false
                if let err { form.errorMessage = "更新に失敗: \(err.localizedDescription)" }
                else { dismiss() }
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

