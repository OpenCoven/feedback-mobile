import FeedbackKit
import SwiftUI

struct SubmitView: View {
    let api: FeedbackAPI
    let auth: AuthStore

    @Environment(\.dismiss) private var dismiss

    @State private var vm: SubmitViewModel?
    @State private var isShowingSignIn = false

    var body: some View {
        NavigationStack {
            Group {
                if let vm {
                    SubmitFormView(vm: vm, isShowingSignIn: $isShowingSignIn, dismiss: dismiss)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("New Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $isShowingSignIn) {
                SignInSheet()
            }
        }
        .task {
            let model = SubmitViewModel(
                api: api,
                isSignedIn: { [auth] in auth.isSignedIn }
            )
            vm = model
        }
        .onChange(of: vm?.needsSignIn) { _, needsSignIn in
            if needsSignIn == true {
                isShowingSignIn = true
            }
        }
    }
}

private struct SubmitFormView: View {
    @ObservedObject var vm: SubmitViewModel
    @Binding var isShowingSignIn: Bool
    let dismiss: DismissAction

    var body: some View {
        Form {
            Section("Board") {
                TextField("Board ID", text: $vm.boardId)
                    .autocorrectionDisabled()
            }

            Section("Post") {
                TextField("Title", text: $vm.title)
                TextField("Description (optional)", text: $vm.content, axis: .vertical)
                    .lineLimit(4...8)
            }

            if let error = vm.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.subheadline)
                }
            }

            Section {
                Button {
                    Task {
                        let success = await vm.submit()
                        if success {
                            dismiss()
                        }
                    }
                } label: {
                    if vm.isSubmitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Submit")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(vm.isSubmitting)
            }
        }
    }
}
