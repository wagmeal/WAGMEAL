//
//  SearchBarView.swift
//  Dogfood
//
//  Created by takumi kowatari on 2025/06/21.
//
import SwiftUI
import UIKit

struct SearchBarView: View {
    @Binding var searchText: String
    @Binding var isSearchActive: Bool
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 0) {
            LINETextField(text: $searchText, isActive: $isSearchActive)
                .frame(height: 38)

            if isSearchActive {
                Button("キャンセル") {
                    searchText = ""
                    isSearchActive = false
                    isFocused.wrappedValue = false
                }
                .foregroundColor(.gray)
                .padding(.leading, 0)
                .padding(.trailing, 8)   // 右側に少し余白を追加
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: isSearchActive)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LINETextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isActive: Bool

    func makeUIView(context: Context) -> UISearchBar {
        let searchBar = UISearchBar()
        searchBar.searchBarStyle = .minimal
        searchBar.placeholder = "検索"
        searchBar.delegate = context.coordinator

        // 🔹 背景を薄いグレーで統一（LINE風）
        let textField = searchBar.searchTextField
        textField.backgroundColor = UIColor.systemGray6
        textField.layer.cornerRadius = 8
        textField.clipsToBounds = true

        // 🔹 アイコン変更（LINE風に統一）
        searchBar.setImage(UIImage(systemName: "magnifyingglass"), for: .search, state: .normal)
        searchBar.setImage(UIImage(systemName: "xmark.circle.fill"), for: .clear, state: .normal)
        searchBar.tintColor = UIColor.systemGray3

        // 🔹 デフォルトの背景を消す
        searchBar.backgroundImage = UIImage()

        return searchBar
    }

    func updateUIView(_ uiView: UISearchBar, context: Context) {
        uiView.text = text

        // フォーカス制御
        if isActive {
            if !uiView.searchTextField.isFirstResponder {
                uiView.searchTextField.becomeFirstResponder()
            }
        } else {
            if uiView.searchTextField.isFirstResponder {
                uiView.searchTextField.resignFirstResponder()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UISearchBarDelegate {
        var parent: LINETextField

        init(_ parent: LINETextField) {
            self.parent = parent
        }

        func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
            DispatchQueue.main.async {
                self.parent.isActive = true
            }
        }

        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            DispatchQueue.main.async {
                self.parent.text = searchText
            }
        }

        func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
            DispatchQueue.main.async {
                self.parent.isActive = false
            }
        }

        func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
            DispatchQueue.main.async {
                self.parent.text = ""
                self.parent.isActive = false
            }
        }

        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            searchBar.resignFirstResponder()
        }
    }
}
#Preview {
    SearchBarPreviewWrapper()
}

private struct SearchBarPreviewWrapper: View {
    @State private var searchText: String = ""
    @State private var isSearchActive: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        SearchBarView(
            searchText: $searchText,
            isSearchActive: $isSearchActive,
            isFocused: $isFocused
        )
    }
}
