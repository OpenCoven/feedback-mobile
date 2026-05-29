@testable import FeedbackKit
import XCTest

final class ModelsTests: XCTestCase {
    func testDecodesPostSummaryAndPageEnvelope() throws {
        let raw = """
        {"data":[{"id":"post_1","title":"A","voteCount":5,"statusId":null,"boardId":"b1","createdAt":"2026-01-01T00:00:00.000Z","hasVoted":true}],
         "meta":{"pagination":{"cursor":null,"hasMore":false}}}
        """
        let json = Data(raw.utf8)
        let page = try JSONDecoder.feedback.decode(Page<PostSummary>.self, from: json)
        XCTAssertEqual(page.data.count, 1)
        XCTAssertEqual(page.data[0].id, "post_1")
        XCTAssertTrue(page.data[0].hasVoted)
        XCTAssertFalse(page.meta?.pagination?.hasMore ?? true)
    }

    func testDecodesBareDataEnvelope() throws {
        let json = Data(#"{"data":{"id":"post_1","title":"A","content":"x","voteCount":3,"statusId":null,"boardId":"b1","createdAt":"2026-01-01T00:00:00.000Z","hasVoted":false}}"#.utf8)
        let env = try JSONDecoder.feedback.decode(Envelope<PostDetail>.self, from: json)
        XCTAssertEqual(env.data.content, "x")
    }
}
