//
//  StarRatingView.swift
//  Dogfood
//
//  Created by takumi kowatari on 2025/07/21.
//

import SwiftUI

struct StarRatingView: View {
    @Binding var rating: Int
    var label: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { index in
                    Image(systemName: index <= rating ? "star.fill" : "star")
                        .foregroundColor(.yellow)
                        .onTapGesture {
                            rating = index
                        }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

