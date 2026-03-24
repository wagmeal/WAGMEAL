//
//  StarStaticView.swift
//  Dogfood
//
//  Created by takumi kowatari on 2025/07/23.
//

import SwiftUI

struct StarStaticView: View {
    var rating: Double
    var label: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { index in
                    Image(systemName: index <= Int(round(rating)) ? "star.fill" : "star")
                        .foregroundColor(.yellow)
                }
            }
        }
    }
}
