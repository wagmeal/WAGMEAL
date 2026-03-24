//
//  SettingsView.swift
//  Dogfood
//
//  Created by takumi kowatari on 2025/11/23.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss   // ← これを追加

    // アプリ共通のベージュカラー
    private let accentBeige = Color(red: 184/255, green: 164/255, blue: 144/255)

    var body: some View {
        NavigationStack {
            List {
                // MARK: - アカウント
                Section {
                    NavigationLink {
                        // プロフィール編集・確認画面（既存の UserProfileView を想定）
                        UserProfileView()
                    } label: {
                        HStack {
                            Text("ユーザー情報")
                            Spacer()
                        }
                    }
                } header: {
                    Text("アカウント")
                }

                // MARK: - サポート
                Section {

                    Button {
                        if let url = URL(string: "https://docs.google.com/forms/d/e/1FAIpQLSdVm523pPJ04JO0VIeCpgILK5SaWpJWVB6Yb3l0zuCSgJnbMA/viewform?usp=dialog") {
                            openURL(url)
                        }
                    } label: {
                        HStack {
                            Text("お問い合わせ")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("サポート")
                }

                // MARK: - アプリ情報
                Section {
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                    NavigationLink {
                        TermsTextView()
                    } label: {
                        HStack {
                            Text("利用規約")
                            Spacer()
                        }
                    }
                    
                    Button {
                        if let url = URL(string: "https://sites.google.com/view/wagmeal-privacy/%E3%83%9B%E3%83%BC%E3%83%A0") {
                            openURL(url)
                        }
                    } label: {
                        HStack {
                            Text("プライバシーポリシー")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                } header: {
                    Text("アプリ情報")
                    
                    
                }

                // MARK: - フッターロゴ
                HStack {
                    Spacer()
                    Image("Logoline")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 150)
                    Spacer()
                }
                .listRowBackground(Color.clear)

                Button {
                    do {
                        try authViewModel.signOut()
                    } catch {
                        print("ログアウトに失敗しました: \(error.localizedDescription)")
                    }
                } label: {
                    Text("ログアウト")
                        .foregroundColor(.red)
                        .padding(.vertical, 8)
                }
                .listRowSeparator(.hidden)
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)


            }
            .navigationTitle("設定")
            .tint(Color.black)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()   // ← シートを閉じる
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(accentBeige)
                    }
                }
            }
        }
    }

    /// Info.plist からアプリのバージョン文字列を取得
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? version : "\(version) (\(build))"
    }
}

#Preview {
    let mockAuth = AuthViewModel()

    // プレビュー用にモックデータを設定
    mockAuth.username = PreviewMockData.userProfile.username

    return SettingsView()
        .environmentObject(mockAuth)
        .environment(\.openURL, OpenURLAction { _ in .handled })
}
