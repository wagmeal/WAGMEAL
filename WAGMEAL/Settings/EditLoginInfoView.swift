import SwiftUI

struct EditLoginInfoView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var currentEmail: String = ""
    @State private var newEmail: String = ""
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmNewPassword: String = ""
    @State private var isSaving = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("現在のログイン情報")) {
                    HStack {
                        Text("登録メールアドレス")
                        Spacer()
                        Text(currentEmail.isEmpty ? "未設定" : currentEmail)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }

                Section(header: Text("変更内容")) {
                    // 新しいメールアドレス（任意）
                    TextField("新しいメールアドレス（任意・確認メールが届きます）", text: $newEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.none)
                        .disableAutocorrection(true)

                    // 現在のパスワード（必須）
                    SecureField("現在のパスワード", text: $currentPassword)

                    // 新しいパスワード（任意）
                    SecureField("新しいパスワード（任意）", text: $newPassword)

                    SecureField("新しいパスワード（確認）", text: $confirmNewPassword)
                }

                if let message = message {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 2)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        updateLoginInfo()
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
            self.currentEmail = mock.email
            return
        }

        authViewModel.loadUserProfile { _, email, _, _ in
            self.currentEmail = email ?? ""
        }
    }

    // MARK: - 更新

    private func updateLoginInfo() {
        // 簡易バリデーション
        guard !currentPassword.isEmpty else {
            message = "現在のパスワードを入力してください"
            return
        }

        if !newEmail.isEmpty, newEmail == currentEmail {
            message = "新しいメールアドレスが現在と同じです"
            return
        }

        if !newPassword.isEmpty, newPassword != confirmNewPassword {
            message = "新しいパスワードが一致しません"
            return
        }

        isSaving = true
        message = nil

        authViewModel.updateLoginInfo(
            currentPassword: currentPassword,
            newEmail: newEmail.isEmpty ? nil : newEmail,
            newPassword: newPassword.isEmpty ? nil : newPassword
        ) { success, error in
            isSaving = false

            if let error = error {
                // ここで Googleログインのみのユーザーなどには、文言を分岐させてもOK
                message = "ログイン情報の更新に失敗しました：\(error.localizedDescription)"
                return
            }

            if success {
                if !newEmail.isEmpty {
                    message = "確認メールを送信しました。新しいメールアドレスの受信箱でリンクを開くと変更が確定します。"
                    // メール変更はリンク踏破まで確定しないため、この画面は閉じずに案内を見せる
                } else if !newPassword.isEmpty {
                    message = "パスワードを更新しました"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismiss()
                    }
                } else {
                    message = "更新する内容がありません"
                }
            } else {
                message = "ログイン情報の更新に失敗しました"
            }
        }
    }
}

#Preview {
    let authVM = AuthViewModel()
    return EditLoginInfoView()
        .environmentObject(authVM)
}
