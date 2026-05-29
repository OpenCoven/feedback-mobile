import Foundation

@MainActor
public final class SubmitViewModel: ObservableObject {
    @Published public var boardId: String = ""
    @Published public var title: String = ""
    @Published public var content: String = ""
    @Published public private(set) var isSubmitting = false
    @Published public private(set) var errorMessage: String?
    @Published public var needsSignIn = false

    private let api: FeedbackAPI
    private let isSignedIn: () -> Bool

    public init(api: FeedbackAPI, isSignedIn: @escaping () -> Bool) {
        self.api = api; self.isSignedIn = isSignedIn
    }

    @discardableResult
    public func submit() async -> Bool {
        errorMessage = nil
        guard isSignedIn() else { needsSignIn = true; return false }
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Title is required."; return false
        }
        guard !boardId.isEmpty else { errorMessage = "Pick a board."; return false }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            _ = try await api.submitPost(boardId: boardId, title: title, content: content)
            return true
        } catch APIError.unauthorized {
            needsSignIn = true; return false
        } catch {
            errorMessage = FeedViewModel.message(for: error); return false
        }
    }
}
