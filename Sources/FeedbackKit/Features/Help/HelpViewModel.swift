import Foundation

@MainActor
public final class HelpViewModel: ObservableObject {
    @Published public private(set) var categories: [HelpCategory] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    private let api: FeedbackAPI
    public init(api: FeedbackAPI) { self.api = api }
    public func load() async {
        isLoading = true; errorMessage = nil
        do { categories = try await api.listHelpCategories() }
        catch { errorMessage = FeedViewModel.message(for: error) }
        isLoading = false
    }
}
