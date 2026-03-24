import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var username: String = ""
    @State private var email: String = ""
    @State private var birthday: Date = Date()
    @State private var gender: String = ""
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

                    // 誕生日
                    DatePicker("誕生日", selection: $birthday, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ja_JP"))

                    // 性別
                    Picker("性別", selection: $gender) {
                        Text("未選択").tag("")
                        Text("男性").tag("男性")
                        Text("女性").tag("女性")
                        Text("その他").tag("その他")
                    }
                    .pickerStyle(.menu)
                }

                if let message = message {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            //.navigationTitle("プロフィールを編集")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveProfile()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("保存")
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear {
                loadFromAuth()
            }
        }
    }

    // MARK: - ロード

    private func loadFromAuth() {
        // プレビュー時は MocData を使用
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            let mock = PreviewMockData.userProfile
            self.username = mock.username
            self.email = mock.email
            self.birthday = mock.birthday
            self.gender = mock.gender
            return
        }

        authViewModel.loadUserProfile { username, email, birthday, gender in
            self.username = username ?? ""
            self.email = email ?? ""
            if let birthday = birthday {
                self.birthday = birthday
            }
            self.gender = gender ?? ""
        }
    }

    // MARK: - 保存

    private func saveProfile() {
        isSaving = true
        message = nil

        authViewModel.updateProfile(
            username: username,
            birthday: birthday,
            gender: gender
        ) { success, error in
            isSaving = false

            if let error = error {
                message = "保存に失敗しました：\(error.localizedDescription)"
            } else if success {
                message = "プロフィールを保存しました"
                // 少し待ってから閉じるなら DispatchQueue.main.asyncAfter で
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismiss()
                }
            } else {
                message = "保存に失敗しました"
            }
        }
    }
}

#Preview {
    let authVM = AuthViewModel()
    return EditProfileView()
        .environmentObject(authVM)
}
