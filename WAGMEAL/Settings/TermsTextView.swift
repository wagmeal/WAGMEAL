//
//  TermsTextView.swift
//  WagMeal
//

import SwiftUI

struct TermsTextView: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("WAGMEAL 利用規約")
                    .font(.title3)
                    .bold()
                    .padding(.bottom, 8)

                // 「プライバシーポリシー」だけをリンク化
                let linkedText = wagmealTermsFullText.replacingOccurrences(
                    of: "プライバシーポリシー",
                    with: "[プライバシーポリシー](https://sites.google.com/view/wagmeal-privacy/%E3%83%9B%E3%83%BC%E3%83%A0)"
                )

                Text(.init(linkedText))
                    .font(.footnote)
                    .foregroundColor(Color(white: 0.4))
                    .multilineTextAlignment(.leading)
                    .tint(Color.blue)
            }
            .padding()
        }
        .navigationTitle("利用規約")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    TermsTextView()
}
