import SwiftUI
import FirebaseAnalytics
import FirebaseCore
import GoogleSignIn
import UIKit

// 戻りURL処理（ログ付き）
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        print("🧪 [GID][AppDelegate] open url:", url.absoluteString)
        let handled = GIDSignIn.sharedInstance.handle(url)
        print("🧪 [GID][AppDelegate] handled =", handled)
        return handled
    }
}

@main
struct DogFoodApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var viewModel = DogFoodViewModel()
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var dogVM = DogProfileViewModel()
    @StateObject private var tabRouter = MainTabRouter()   // ★ 追加


    @AppStorage("selectedDogID") private var selectedDogID: String?
    @State private var isSplashActive = false

    init() {
        // ✅ Xcode Previews では Firebase/Analytics 初期化をしない（タイムアウト対策）
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            UITabBar.appearance().tintColor = UIColor(red: 184/255, green: 164/255, blue: 144/255, alpha: 1.0)
            UITabBar.appearance().unselectedItemTintColor = UIColor.gray
            UITabBar.appearance().backgroundColor = UIColor.systemBackground
            UITabBar.appearance().isTranslucent = false
            return
        }

        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        Analytics.setAnalyticsCollectionEnabled(true)
        // 🔴 強制イベント（これが出なければ100%設定問題）
        Analytics.logEvent("debug_force_event", parameters: [
            "source": "app_launch"
        ])

        print("🔥 debug_force_event sent")
        
        print("Firebase clientID:", FirebaseApp.app()?.options.clientID as Any)

        UITabBar.appearance().tintColor = UIColor(red: 184/255, green: 164/255, blue: 144/255, alpha: 1.0)
        UITabBar.appearance().unselectedItemTintColor = UIColor.gray
        UITabBar.appearance().backgroundColor = UIColor.systemBackground
        UITabBar.appearance().isTranslucent = false
    }

    var body: some Scene {
        WindowGroup {
            // ★ ここで分岐の結果をまとめて 1つの View にする
            Group {
                if isSplashActive {
                    // ✅ ゲスト利用を許可：ログアウト状態でもメインタブへ
                    //    ※ ただし「ログイン済み」なのに規約/プロフィールが未完了の場合は先に完了させる

                    // ① ログイン済みだが規約未同意 → 規約画面へ
                    if authVM.isLoggedIn, authVM.requiresTermsAgreement {
                        TermsAgreementView()
                            .environmentObject(authVM)

                    // ② ログイン済み & 規約同意済み かつ プロフィール未入力 → プロフィール入力画面へ
                    } else if authVM.isLoggedIn, authVM.requiresProfileSetup {
                        ProfileSetupView()
                            .environmentObject(authVM)

                    // ③ 上記以外（ログイン/ログアウト問わず） → メインタブへ
                    } else {
                        MainTabView()
                            .environmentObject(authVM)
                            .environmentObject(viewModel)
                            .environmentObject(dogVM)
                            .environmentObject(tabRouter)
                    }
                } else {
                    SplashView(isActive: $isSplashActive)
                }
            }
            // ★ 共通のラッパーに onOpenURL を付与（どの分岐でも拾える）
            .onOpenURL { url in
                let reversed = Bundle.main.object(forInfoDictionaryKey: "REVERSED_CLIENT_ID") as? String ?? "(nil)"
                let schemeMatch = (url.scheme == reversed)
                print("🧪 [GID][onOpenURL @App] url =", url.absoluteString)
                print("🧪 [GID][onOpenURL @App] schemeMatch =", schemeMatch, "expected:", reversed)
                let handled = GIDSignIn.sharedInstance.handle(url)
                print("🧪 [GID][onOpenURL @App] handled =", handled)
            }
        }
    }
}
