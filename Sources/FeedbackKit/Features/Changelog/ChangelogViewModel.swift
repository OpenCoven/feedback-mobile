import Foundation

@MainActor
public final class ChangelogViewModel: ObservableObject {
    @Published public private(set) var entries: [ChangelogEntry] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    private let api: FeedbackAPI
    private let cache: ContentCache
    private let cacheKey = "changelog"
    public init(api: FeedbackAPI, cache: ContentCache = ContentCache()) {
        self.api = api
        self.cache = cache
    }
    public func load() async {
        isLoading = true; errorMessage = nil
        do {
            entries = try await api.listChangelog(cursor: nil).data
            try? cache.save(entries, as: cacheKey)
        } catch {
            if entries.isEmpty {
                if let cached = try? cache.load(cacheKey, as: [ChangelogEntry].self) {
                    entries = cached
                } else {
                    errorMessage = FeedViewModel.message(for: error)
                }
            }
        }
        isLoading = false
    }
}
