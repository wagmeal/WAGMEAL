import SwiftUI

struct ProfileSetupView: View {
    @EnvironmentObject var authVM: AuthViewModel

    @State private var genderEnabled: Bool = true
    @State private var gender: String = "男性"
    @State private var birthday: Date? = Date()
    @State private var birthdayEnabled: Bool = true
    @State private var username: String = ""
    @State private var isSaving = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("プロフィール")) {
                    // ユーザー名
                    TextField("ユーザー名", text: $username)
                        .textInputAutocapitalization(.none)
                        .disableAutocorrection(true)

                    // 誕生日（任意）
                    Toggle("誕生日を登録する（任意）", isOn: $birthdayEnabled)
                        .tint(Color(red: 184/255, green: 164/255, blue: 144/255))

                    if birthdayEnabled {
                        DatePicker(
                            "誕生日",
                            selection: Binding(
                                get: { birthday ?? Date() },
                                set: { birthday = $0 }
                            ),
                            displayedComponents: .date
                        )
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                    }

                    // 性別（任意）
                    Toggle("性別を登録する（任意）", isOn: $genderEnabled)
                        .tint(Color(red: 184/255, green: 164/255, blue: 144/255))

                    if genderEnabled {
                        Picker("性別", selection: $gender) {
                            Text("男性").tag("男性")
                            Text("女性").tag("女性")
                            Text("その他").tag("その他")
                        }
                        .pickerStyle(.menu)
                    }
                }

                if let message = message {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            VStack {
                Button(action: { saveProfile() }) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("保存")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(red: 184/255, green: 164/255, blue: 144/255))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - 保存

    private func saveProfile() {
        isSaving = true
        message = nil

        authVM.updateProfile(
            username: username,
            birthday: birthdayEnabled ? birthday : nil,
            gender: genderEnabled ? gender : nil
        ) { success, error in
            isSaving = false

            if let error = error {
                message = "保存に失敗しました：\(error.localizedDescription)"
            } else if success {
                message = "プロフィールを保存しました"
                // 入力完了 → フラグを下ろす
                authVM.requiresProfileSetup = false
            } else {
                message = "保存に失敗しました"
            }
        }
    }
}

#Preview {
    let authVM = AuthViewModel()
    return ProfileSetupView()
        .environmentObject(authVM)
}
