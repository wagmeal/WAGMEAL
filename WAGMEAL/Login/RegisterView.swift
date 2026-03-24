//
//  RegisterView.swift
//  Dogfood
//
//  Created by takumi kowatari on 2025/07/12.
//

import SwiftUI

struct RegisterView: View {
    enum Gender: String, CaseIterable, Identifiable {
        case male = "男性"
        case female = "女性"
        case other = "その他"

        var id: String { rawValue }
    }

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authVM: AuthViewModel

    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var birthday = Date()
    @State private var selectedGender: Gender = .male
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 24) {
            Text("アカウント作成")
                .font(.largeTitle)
                .bold()

            // ログイン情報セクション
            VStack(alignment: .leading, spacing: 12) {
                Text("ログイン情報")
                    .font(.headline)

                TextField("メールアドレス", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)

                SecureField("パスワード", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                SecureField("パスワード（確認）", text: $confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // ユーザー情報セクション
            VStack(alignment: .leading, spacing: 12) {
                Text("ユーザー情報")
                    .font(.headline)

                TextField("ユーザー名", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                DatePicker("誕生日", selection: $birthday, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .environment(\.locale, Locale(identifier: "ja_JP"))

                HStack {
                    Text("性別")
                    Spacer()
                    Menu {
                        ForEach(Gender.allCases) { gender in
                            Button(gender.rawValue) {
                                selectedGender = gender
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedGender.rawValue)
                                .foregroundColor(.black)
                            Image(systemName: "chevron.down")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Button(action: {
                Task {
                    await register()
                }
            }) {
                if isLoading {
                    ProgressView()
                } else {
                    Text("アカウントを作成")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 184/255, green: 164/255, blue: 144/255))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .disabled(isLoading || username.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty)

            Button("ログイン画面に戻る") {
                dismiss()
            }
            .font(.footnote)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top) // ← ここ追加
        .padding(.horizontal)
        .padding(.top, 16)   // 好きな量だけ上の余白（なければ消してOK）
        .padding(.bottom)
    }

    private func register() async {
        errorMessage = nil

        guard password == confirmPassword else {
            errorMessage = "パスワードが一致しません"
            return
        }

        isLoading = true
        do {
            try await authVM.signUp(
                email: email,
                password: password,
                username: username,
                birthday: birthday,
                gender: selectedGender.rawValue
            )
        } catch {
            errorMessage = "登録に失敗しました：\(error.localizedDescription)"
        }
        isLoading = false
    }
}

#Preview {
    RegisterView()
        .environmentObject(AuthViewModel())
}
