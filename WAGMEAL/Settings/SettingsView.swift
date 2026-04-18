//
//  SettingsView.swift
//  Dogfood
//
//  Created by takumi kowatari on 2025/11/23.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var tabRouter: MainTabRouter
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @State private var showLoginSheet = false
    @State private var showLogoutAlert = false

    // アプリ共通のベージュカラー
    private let accentBeige = Color(red: 184/255, green: 164/255, blue: 144/255)

    var body: some View {
        NavigationStack {
            List {
                if authViewModel.isLoggedIn {
                    // MARK: - アカウント
                    Section {
                        NavigationLink {
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
                        showLogoutAlert = true
                    } label: {
                        Text("ログアウト")
                            .foregroundColor(.red)
                            .padding(.vertical, 8)
                    }
                    .listRowSeparator(.hidden)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)

                } else {
                    // MARK: - サポート（ログアウト時）
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

                    // MARK: - アプリ情報（ログアウト時）
                    Section {
                        HStack {
                            Text("バージョン")
                            Spacer()
                            Text(appVersion)
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("アプリ情報")
                    }

                    // MARK: - ログイン
                    Button {
                        showLoginSheet = true
                    } label: {
                        Text("ログイン")
                            .foregroundColor(.blue)
                            .padding(.vertical, 8)
                    }
                    .listRowSeparator(.hidden)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("設定")
            .tint(Color.black)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(accentBeige)
                    }
                }
            }
            .sheet(isPresented: $showLoginSheet) {
                LoginView()
                    .environmentObject(authViewModel)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .alert("ログアウトしますか？", isPresented: $showLogoutAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("ログアウト", role: .destructive) {
                    do {
                        try authViewModel.signOut()
                        tabRouter.selectedTab = .myDog
                        dismiss()
                    } catch {
                        print("ログアウトに失敗しました: \(error.localizedDescription)")
                    }
                }
            }
            .onChange(of: authViewModel.isLoggedIn) { isLoggedIn in
                if isLoggedIn {
                    showLoginSheet = false
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

#Preview("Settings / Logged Out") {
    let loggedOutAuth = AuthViewModel()
    loggedOutAuth.isLoggedIn = false
    loggedOutAuth.username = nil
    let router = MainTabRouter()

    return SettingsView()
        .environmentObject(loggedOutAuth)
        .environmentObject(router)
        .environment(\.openURL, OpenURLAction { _ in .handled })
}

#Preview("Settings / Logged In") {
    let loggedInAuth = AuthViewModel()
    loggedInAuth.isLoggedIn = true
    loggedInAuth.username = PreviewMockData.userProfile.username
    let router = MainTabRouter()

    return SettingsView()
        .environmentObject(loggedInAuth)
        .environmentObject(router)
        .environment(\.openURL, OpenURLAction { _ in .handled })
}
