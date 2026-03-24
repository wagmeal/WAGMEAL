import SwiftUI

struct MainHeaderView: View {
    @State private var isShowingSettings = false

    var body: some View {
        ZStack {
            // ベージュ背景
            Color(red: 184/255, green: 164/255, blue: 144/255)
                .edgesIgnoringSafeArea(.top)

            ZStack {
                // 中央タイトル
                Text("WAG MEAL")
                    .font(.system(size: 36, weight: .light))
                    .kerning(4)
                    .foregroundColor(.white)

                // 右上の歯車ボタン
                HStack {
                    Spacer()
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .frame(height: 60)
        // 下から設定画面を表示
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        MainHeaderView()
        Spacer() // 背景とのバランス用
    }
}
