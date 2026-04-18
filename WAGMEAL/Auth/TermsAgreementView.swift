import SwiftUI
import FirebaseCore
import GoogleSignIn
import UIKit


// MARK: - TermsAgreementView
struct TermsAgreementView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var isAgreeing: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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

                Divider()

                VStack(spacing: 12) {
                    Button {
                        Task {
                            await agree()
                        }
                    } label: {
                        if isAgreeing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text("同意して利用を開始する")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .disabled(isAgreeing)
                    .background(isAgreeing ? Color.gray.opacity(0.4) : Color(red: 184/255, green: 164/255, blue: 144/255))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
                .background(
                    Color(.systemBackground)
                        .ignoresSafeArea(edges: .bottom)
                )
            }
            .navigationTitle("利用規約")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func agree() async {
        guard !isAgreeing else { return }
        isAgreeing = true
        await authVM.agreeToCurrentTerms()
        isAgreeing = false
    }
}

// MARK: - Preview
struct TermsAgreementView_Previews: PreviewProvider {
    static var previews: some View {
        TermsAgreementView()
            .environmentObject(AuthViewModel())
    }
}
