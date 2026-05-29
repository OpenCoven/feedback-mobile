import Foundation

@MainActor
public final class ChangelogViewModel: ObservableObject {
    @Published public private(set) var entries: [ChangelogEntry] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    private let api: FeedbackAPI
    public init(api: FeedbackAPI) { self.api = api }
    public func load() async {
        isLoading = true; errorMessage = nil
        do { entries = try await api.listChangelog(cursor: nil).data }
        catch { errorMessage = FeedViewModel.message(for: error) }
        isLoading = false
    }
}
