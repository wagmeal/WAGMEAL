import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showResetSheet = false
    @State private var resetEmail = ""
    @State private var resetInfoMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                
                Image("Applogoreverse")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200) // アイコンサイズ
                

                // メールアドレス入力
                TextField("メールアドレス", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)    // ★ 推奨
                    .autocorrectionDisabled(true)            // ★ 推奨

                // パスワード入力
                SecureField("パスワード", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                // エラー表示
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                // ログインボタン（メール/パス）
                Button {
                    Task { await signIn() }
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("ログイン")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(red: 184/255, green: 164/255, blue: 144/255))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .disabled(isLoading || email.isEmpty || password.isEmpty)
                
                // 既存の「ログイン」ボタンの下あたりに追加
                Button("パスワードを忘れた方") {
                    resetEmail = email // 入力中のメールがあれば流用
                    showResetSheet = true
                }
                .font(.footnote)
                .padding(.top, 4)

                // シート本体
                .sheet(isPresented: $showResetSheet) {
                    NavigationStack {
                        VStack(spacing: 16) {
                            Text("パスワード再設定メールを送信します")
                                .font(.headline)

                            TextField("登録メールアドレス", text: $resetEmail)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)

                            if let msg = resetInfoMessage {
                                Text(msg)
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }

                            Button {
                                Task {
                                    await sendReset()
                                }
                            } label: {
                                Text("メールを送信")
                                    .bold()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(red: 184/255, green: 164/255, blue: 144/255))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .disabled(resetEmail.isEmpty)

                            Spacer()
                        }
                        .padding()
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("閉じる") { showResetSheet = false }
                            }
                        }
                    }
                }

                // 区切り
                HStack {
                    Rectangle().frame(height: 1).opacity(0.15)
                    Text("または")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Rectangle().frame(height: 1).opacity(0.15)
                }

                // ★ Googleでログイン
                Button {
                    Task {
                        await signInWithGoogle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image("googlelogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40) // アイコンサイズ
                        Text("Googleでログイン")
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black.opacity(0.15), lineWidth: 1)
                    )
                }
                .disabled(isLoading)


                // 新規登録へ
                NavigationLink("アカウントを作成する", destination: RegisterView())
                    .font(.footnote)
                
            }
            .padding()
        }
    }

    private func signIn() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await authVM.signIn(email: email, password: password)
        } catch {
            errorMessage = "ログインに失敗しました：\(error.localizedDescription)"
        }
    }

    // ★ Google サインイン呼び出し
    private func signInWithGoogle() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        guard let vc = UIApplication.topViewController() else {
            errorMessage = "内部エラー（presenting VC 取得失敗）"
            return
        }
        do {
            try await authVM.signInWithGoogle(presentingViewController: vc)
        } catch {
            errorMessage = "Googleログインに失敗しました：\(error.localizedDescription)"
        }
    }
    
    private func sendReset() async {
        // 表示メッセージは常に同じ（ユーザー列挙対策）
        let genericMsg = "該当するアカウントがある場合、再設定メールを送信しました。受信トレイをご確認ください。"

        do {
            try await authVM.sendPasswordReset(email: resetEmail.trimmingCharacters(in: .whitespaces))
            resetInfoMessage = genericMsg
        } catch {
            // ここでも同じメッセージにしておくのが安全
            resetInfoMessage = genericMsg
            // デバッグしたいときだけ内部ログ
            print("Password reset error:", error.localizedDescription)
        }
    }
}

// 現在のトップVCを取得するユーティリティ（★ 追加）
extension UIApplication {
    static func topViewController(
        base: UIViewController? = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController
    ) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
}


#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
