import FirebaseAuth
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

                // ★ Googleでログイン（Appleより上に表示）
                Button {
                    Task {
                        await signInWithGoogle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image("googlelogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                        Text("Googleでログイン")
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48) // ★ Appleと高さを揃える
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black.opacity(0.15), lineWidth: 1)
                    )
                }
                .disabled(isLoading)

                // ★ Appleでログイン
                Button {
                    Task {
                        await signInWithApple()
                    }
                } label: {
                    HStack {
                        Image(systemName: "applelogo")
                        Text("Appleでサインイン")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(10)
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
            // Firebase Auth のエラーコードを解析して日本語メッセージを出し分け
            if let nsError = error as NSError?,
               let authError = AuthErrorCode(_bridgedNSError: nsError) {
                let code = authError.code

                print("🔥 Email sign-in error:", code, "/", nsError.localizedDescription)

                switch code {
                case .wrongPassword, .userNotFound:
                    errorMessage = "メールアドレスまたはパスワードが間違っています。"

                case .invalidEmail:
                    errorMessage = "メールアドレスの形式が正しくありません。"

                case .tooManyRequests:
                    errorMessage = "試行回数が多すぎます。しばらく時間をおいて再度お試しください。"

                case .networkError:
                    errorMessage = "ネットワークエラーが発生しました。通信環境を確認してください。"

                default:
                    errorMessage = "ログインに失敗しました。（コード: \(code.rawValue)）"
                }
            } else {
                errorMessage = "ログインに失敗しました：\(error.localizedDescription)"
            }
        }
    }

    // ★ Google サインイン呼び出し
    private func signInWithGoogle() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        guard let vc = UIApplication.topViewController() else {
            errorMessage = "内部エラー（画面情報の取得に失敗しました）"
            return
        }

        do {
            try await authVM.signInWithGoogle(presentingViewController: vc)
        } catch {
            // Google サインイン → FirebaseAuth 連携時のエラーを解析
            if let nsError = error as NSError?,
               let authError = AuthErrorCode(_bridgedNSError: nsError) {
                let code = authError.code

                print("🔥 Google sign-in error:", code, "/", nsError.localizedDescription)

                switch code {
                case .invalidCredential:
                    errorMessage = "ログイン情報が無効になっています。一度アカウントを作り直すか、別のログイン方法をお試しください。"

                case .accountExistsWithDifferentCredential:
                    errorMessage = "同じメールアドレスで別のログイン方法が登録されています。メールアドレスとパスワードでのログインをお試しください。"

                case .networkError:
                    errorMessage = "ネットワークエラーが発生しました。通信環境を確認してください。"

                default:
                    errorMessage = "Googleログインに失敗しました。（コード: \(code.rawValue)）"
                }
            } else {
                errorMessage = "Googleログインに失敗しました：\(error.localizedDescription)"
            }
        }
    }

    private func signInWithApple() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        guard
            let window = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
                .first
        else {
            errorMessage = "内部エラー（ウィンドウ情報の取得に失敗しました）"
            return
        }

        do {
            try await authVM.signInWithApple(presentationAnchor: window)
        } catch {
            errorMessage = "Appleログインに失敗しました：\(error.localizedDescription)"
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
