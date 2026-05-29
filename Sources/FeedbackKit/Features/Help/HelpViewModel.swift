import Foundation

@MainActor
public final class HelpViewModel: ObservableObject {
    @Published public private(set) var categories: [HelpCategory] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    private let api: FeedbackAPI
    private let cache: ContentCache
    private let cacheKey = "help_categories"
    public init(api: FeedbackAPI, cache: ContentCache = ContentCache()) {
        self.api = api
        self.cache = cache
    }
    public func load() async {
        isLoading = true; errorMessage = nil
        do {
            categories = try await api.listHelpCategories()
            try? cache.save(categories, as: cacheKey)
        } catch {
            if categories.isEmpty {
                if let cached = try? cache.load(cacheKey, as: [HelpCategory].self) {
                    categories = cached
                } else {
                    errorMessage = FeedViewModel.message(for: error)
                }
            }
        }
        isLoading = false
    }
}
