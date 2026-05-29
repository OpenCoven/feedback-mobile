import FeedbackKit
import SwiftUI

struct SignInSheet: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var code = ""
    @State private var codeSent = false
    @State private var isSending = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .disabled(codeSent)
                }

                if codeSent {
                    Section {
                        TextField("6-digit code", text: $code)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                    }
                }

                if let error = auth.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }

                Section {
                    if !codeSent {
                        Button {
                            Task { await sendCode() }
                        } label: {
                            if isSending {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Send Code")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                    } else {
                        Button {
                            Task { await verify() }
                        } label: {
                            if isSending {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Verify")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)

                        Button("Resend Code") {
                            code = ""
                            codeSent = false
                        }
                        .buttonStyle(.borderless)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onChange(of: auth.isSignedIn) { _, isSignedIn in
            if isSignedIn {
                dismiss()
            }
        }
    }

    private func sendCode() async {
        isSending = true
        do {
            try await auth.requestCode(email: email)
            codeSent = true
        } catch {
            // errorMessage surfaced through auth.errorMessage if set by AuthStore
        }
        isSending = false
    }

    private func verify() async {
        isSending = true
        await auth.verify(email: email, code: code)
        isSending = false
    }
}
