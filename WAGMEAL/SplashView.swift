//
//  SplashView.swift
//  Dogfood
//
//  Created by takumi kowatari on 2025/08/03.
//

import SwiftUI

struct SplashView: View {
    @Binding var isActive: Bool
    @State private var opacity: Double = 1.0

    var body: some View {
        ZStack {
            Image("Splash")
                .resizable()
                .scaledToFit()
                .frame(width: 800, height: 900)
                .opacity(opacity)
                .onAppear {
                    // 1.5秒後にフェードアウト
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeOut(duration: 1.0)) {
                            opacity = 0.0
                        }
                        // アニメーションが終わるタイミングで遷移
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            isActive = true
                        }
                    }
                }
        }
        .ignoresSafeArea()
    }
}

