//
//  UserProfileView.swift
//  Dogfood
//
//  Created by takumi kowatari on 2025/11/23.
//
import SwiftUI

struct UserProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var username: String = ""
    @State private var email: String = ""
    @State private var birthday: Date = Date()
    @State private var gender: String = ""
    @State private var isSaving = false
    @State private var saveMessage: String?

    private var formattedBirthday: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .medium
        return formatter.string(from: birthday)
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - ログイン情報
                Section {
                    HStack {
                        Text("登録メールアドレス")
                        Spacer()
                        Text(email.isEmpty ? "未設定" : email)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("パスワード")
                        Spacer()
                        Text("******")
                            .foregroundColor(.secondary)
                    }

                    NavigationLink {
                        EditLoginInfoView()
                    } label: {
                        HStack {
                            Spacer()
                            Text("ログイン情報を変更する")
                            Spacer()
                        }
                    }
                } header: {
                    Text("ログイン情報")
                }
                // MARK: - プロフィール
                Section {
                    HStack {
                        Text("ユーザー名")
                        Spacer()
                        Text(username.isEmpty ? "未設定" : username)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("誕生日")
                        Spacer()
                        Text(formattedBirthday)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("性別")
                        Spacer()
                        Text(gender.isEmpty ? "未設定" : gender)
                            .foregroundColor(.secondary)
                    }

                    NavigationLink {
                        EditProfileView()
                    } label: {
                        HStack {
                            Spacer()
                            Text("プロフィールを変更する")
                            Spacer()
                        }
                    }
                } header: {
                    Text("プロフィール")
                }
                if let message = saveMessage {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("ユーザー情報")
            .onAppear {
                // Xcode プレビュー時は Firebase にアクセスせず MocData を使用
                if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                    let mock = PreviewMockData.userProfile
                    self.username = mock.username
                    self.email = mock.email
                    self.birthday = mock.birthday
                    self.gender = mock.gender
                } else {
                    loadFromAuth()
                }
            }
        }
    }

    /// AuthViewModel から初期値をロード
    private func loadFromAuth() {
        authViewModel.loadUserProfile { username, email, birthday, gender in
            self.username = username ?? ""
            self.email = email ?? ""
            if let birthday = birthday {
                self.birthday = birthday
            }
            self.gender = gender ?? ""
        }
    }

    /// プロフィール保存処理
    private func saveProfile() {
        isSaving = true
        saveMessage = nil

        authViewModel.updateProfile(username: username, birthday: birthday, gender: gender) { success, error in
            isSaving = false
            if let error = error {
                saveMessage = "保存に失敗しました：\(error.localizedDescription)"
            } else if success {
                saveMessage = "プロフィールを保存しました"
            } else {
                saveMessage = "保存に失敗しました"
            }
        }
    }
}

#Preview {
    // プレビュー用のダミー
    let authVM = AuthViewModel()
    // 必要ならここで authVM.currentUser 的なものをモックセット

    return UserProfileView()
        .environmentObject(authVM)
}
