@testable import FeedbackKit
import XCTest

@MainActor
final class ReadOnlyViewModelsTests: XCTestCase {
    func testChangelogLoads() async {
        final class API: MockFeedbackAPI {
            override func listChangelog(cursor: String?) async throws -> Page<ChangelogEntry> {
                Page(data: [ChangelogEntry(id: "cl_1", title: "v1", content: nil, publishedAt: .init())], meta: nil)
            }
        }
        let vm = ChangelogViewModel(api: API())
        await vm.load()
        XCTAssertEqual(vm.entries.map(\.id), ["cl_1"])
    }

    func testHelpLoadsCategories() async {
        final class API: MockFeedbackAPI {
            override func listHelpCategories() async throws -> [HelpCategory] {
                [HelpCategory(id: "cat_1", name: "Start", slug: "start", description: nil)]
            }
        }
        let vm = HelpViewModel(api: API())
        await vm.load()
        XCTAssertEqual(vm.categories.map(\.slug), ["start"])
    }
}
