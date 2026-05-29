import FeedbackKit
import SwiftUI

struct AccountTabView: View {
    @EnvironmentObject private var auth: AuthStore

    @State private var isShowingSignIn = false

    var body: some View {
        NavigationStack {
            List {
                if auth.isSignedIn {
                    Section {
                        Label("Signed in", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    }

                    Section {
                        Button(role: .destructive) {
                            auth.signOut()
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                } else {
                    Section {
                        Label("Not signed in", systemImage: "person.crop.circle.badge.xmark")
                            .foregroundStyle(.secondary)
                    }

                    Section {
                        Button {
                            isShowingSignIn = true
                        } label: {
                            Label("Sign In", systemImage: "person.crop.circle.badge.checkmark")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Account")
            .sheet(isPresented: $isShowingSignIn) {
                SignInSheet()
            }
        }
    }
}
