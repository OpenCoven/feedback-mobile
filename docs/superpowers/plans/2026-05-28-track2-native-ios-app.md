# Track 2 — Native Give-Feedback iOS App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native SwiftUI give-feedback app in `feedback-mobile` that browses boards/posts, votes, comments, submits, and reads changelog + help against the Track 1 public API — with content that updates live from the server.

**Architecture:** A new SPM library target `FeedbackKit` holds all logic (typed API client, `AuthStore`, observable view models, models, cache) so it is unit-testable via `swift test` on macOS (no iOS SDK needed). A thin SwiftUI app target (`FeedbackPortalApp`) renders a 4-tab UI (Feedback · Changelog · Help · Account) over `FeedbackKit`. Reads are anonymous; writes attach a better-auth bearer token (email-OTP sign-in, stored in Keychain). The app is independent of the existing `OpenCovenFeedback` widget SDK.

**Tech Stack:** Swift 5.9+, SwiftUI, Swift Concurrency, `URLSession`, `XCTest`. The API client is a hand-written `FeedbackAPI` protocol + a `URLSession`-backed implementation decoding `Codable` models that mirror the Track 1 OpenAPI contract. (A later task can swap the implementation for swift-openapi-generator output behind the same protocol without touching view models.)

**Prerequisite:** Track 1 (`/api/public/v1`) contract is defined. View models are tested against a mock conforming to `FeedbackAPI`, so this track can proceed before the live API exists.

**Repo:** `feedback-mobile` (this repo). New code goes under `Sources/FeedbackKit/` and `App/` with tests in `Tests/FeedbackKitTests/`.

---

## File Structure

- `Package.swift` — add `FeedbackKit` library target + `FeedbackKitTests` test target (keep the existing `OpenCovenFeedback` SDK targets untouched).
- `Sources/FeedbackKit/Config/AppConfig.swift` — instance URL.
- `Sources/FeedbackKit/Models/*.swift` — `Board`, `PostSummary`, `PostDetail`, `Comment`, `ChangelogEntry`, `HelpCategory`, `HelpArticle`, `Page<T>` (Codable, mirror the API JSON).
- `Sources/FeedbackKit/API/FeedbackAPI.swift` — protocol (all endpoints).
- `Sources/FeedbackKit/API/HTTPFeedbackAPI.swift` — `URLSession` implementation.
- `Sources/FeedbackKit/API/APIError.swift` — typed errors incl. `.unauthorized`.
- `Sources/FeedbackKit/Auth/TokenStore.swift` — Keychain-backed token persistence (protocol + Keychain impl + in-memory test impl).
- `Sources/FeedbackKit/Auth/AuthStore.swift` — observable sign-in state + email-OTP flow.
- `Sources/FeedbackKit/Features/Feed/FeedViewModel.swift`, `Detail/PostDetailViewModel.swift`, `Submit/SubmitViewModel.swift`, `Changelog/ChangelogViewModel.swift`, `Help/HelpViewModel.swift`.
- `Sources/FeedbackKit/Cache/ContentCache.swift` — last-feed/changelog/help disk cache.
- `App/FeedbackPortalApp/*.swift` — `@main` app, `RootTabView`, per-tab SwiftUI screens, `SignInSheet`. (UI; not unit-tested.)
- `App/project.yml` additions or a new XcodeGen target; CI builds it for iOS Simulator.

Each view model has one responsibility and depends only on `FeedbackAPI` + `AuthStore`, never on `URLSession` directly — so all are testable with a mock.

---

## Task 1: Add the `FeedbackKit` library + test targets

**Files:**
- Modify: `Package.swift`
- Create: `Sources/FeedbackKit/FeedbackKit.swift` (placeholder so the target compiles)
- Create: `Tests/FeedbackKitTests/SmokeTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/FeedbackKitTests/SmokeTests.swift
import XCTest
@testable import FeedbackKit

final class SmokeTests: XCTestCase {
    func testModuleLoads() {
        XCTAssertEqual(FeedbackKit.name, "FeedbackKit")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter FeedbackKitTests`
Expected: FAIL — no target `FeedbackKit`.

- [ ] **Step 3: Add the targets + placeholder**

In `Package.swift`, add to `products` and `targets`:

```swift
.library(name: "FeedbackKit", targets: ["FeedbackKit"]),
```

```swift
.target(name: "FeedbackKit", path: "Sources/FeedbackKit"),
.testTarget(name: "FeedbackKitTests", dependencies: ["FeedbackKit"], path: "Tests/FeedbackKitTests"),
```

```swift
// Sources/FeedbackKit/FeedbackKit.swift
public enum FeedbackKit {
    public static let name = "FeedbackKit"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter FeedbackKitTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/FeedbackKit/FeedbackKit.swift Tests/FeedbackKitTests/SmokeTests.swift
git commit -m "feat(app): scaffold FeedbackKit library + test target"
```

---

## Task 2: Codable models mirroring the API contract

**Files:**
- Create: `Sources/FeedbackKit/Models/Models.swift`
- Test: `Tests/FeedbackKitTests/ModelsTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import FeedbackKit

final class ModelsTests: XCTestCase {
    func testDecodesPostSummaryAndPageEnvelope() throws {
        let json = """
        {"data":[{"id":"post_1","title":"A","voteCount":5,"statusId":null,"boardId":"b1","createdAt":"2026-01-01T00:00:00.000Z","hasVoted":true}],
         "meta":{"pagination":{"cursor":null,"hasMore":false}}}
        """.data(using: .utf8)!
        let page = try JSONDecoder.feedback.decode(Page<PostSummary>.self, from: json)
        XCTAssertEqual(page.data.count, 1)
        XCTAssertEqual(page.data[0].id, "post_1")
        XCTAssertTrue(page.data[0].hasVoted)
        XCTAssertFalse(page.meta?.pagination?.hasMore ?? true)
    }

    func testDecodesBareDataEnvelope() throws {
        let json = #"{"data":{"id":"post_1","title":"A","content":"x","voteCount":3,"statusId":null,"boardId":"b1","createdAt":"2026-01-01T00:00:00.000Z","hasVoted":false}}"#.data(using: .utf8)!
        let env = try JSONDecoder.feedback.decode(Envelope<PostDetail>.self, from: json)
        XCTAssertEqual(env.data.content, "x")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ModelsTests`
Expected: FAIL — `Page`/`PostSummary` undefined.

- [ ] **Step 3: Write minimal implementation**

```swift
// Sources/FeedbackKit/Models/Models.swift
import Foundation

public struct Pagination: Codable, Sendable, Equatable {
    public let cursor: String?
    public let hasMore: Bool
}
public struct Meta: Codable, Sendable, Equatable {
    public let pagination: Pagination?
}
public struct Page<T: Codable & Sendable & Equatable>: Codable, Sendable, Equatable {
    public let data: [T]
    public let meta: Meta?
}
public struct Envelope<T: Codable & Sendable & Equatable>: Codable, Sendable, Equatable {
    public let data: T
}

public struct Board: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let slug: String
    public let description: String?
    public let postCount: Int?
}
public struct PostSummary: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let voteCount: Int
    public let statusId: String?
    public let boardId: String
    public let createdAt: Date
    public let hasVoted: Bool
}
public struct PostDetail: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let content: String
    public let voteCount: Int
    public let statusId: String?
    public let boardId: String
    public let createdAt: Date
    public let hasVoted: Bool
}
public struct Comment: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let content: String
    public let authorName: String
    public let createdAt: Date
    public let replies: [Comment]
}
public struct ChangelogEntry: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let content: String?
    public let publishedAt: Date?
}
public struct HelpCategory: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let slug: String
    public let description: String?
}
public struct HelpArticle: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let slug: String
    public let title: String
    public let content: String
    public let categoryId: String
}
public struct VoteResult: Codable, Sendable, Equatable {
    public let voted: Bool
    public let voteCount: Int
}

public extension JSONDecoder {
    /// ISO-8601 with fractional seconds, matching the API's `toISOString()` output.
    static let feedback: JSONDecoder = {
        let d = JSONDecoder()
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        d.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            if let date = f.date(from: s) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date: \(s)"))
        }
        return d
    }()
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter ModelsTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/FeedbackKit/Models/Models.swift Tests/FeedbackKitTests/ModelsTests.swift
git commit -m "feat(app): Codable models + JSON envelopes"
```

---

## Task 3: `FeedbackAPI` protocol + `APIError`

**Files:**
- Create: `Sources/FeedbackKit/API/FeedbackAPI.swift`, `Sources/FeedbackKit/API/APIError.swift`
- Test: `Tests/FeedbackKitTests/MockFeedbackAPI.swift` (test helper — no assertions yet)

- [ ] **Step 1: Write the failing test** (a mock that must conform to the protocol)

```swift
// Tests/FeedbackKitTests/MockFeedbackAPI.swift
@testable import FeedbackKit
import Foundation

final class MockFeedbackAPI: FeedbackAPI, @unchecked Sendable {
    var posts: [PostSummary] = []
    var voteResult = VoteResult(voted: true, voteCount: 1)
    var submitted: (boardId: String, title: String, content: String)?
    var shouldUnauthorize = false

    func listPosts(boardId: String?, sort: PostSort, cursor: String?) async throws -> Page<PostSummary> {
        Page(data: posts, meta: Meta(pagination: Pagination(cursor: nil, hasMore: false)))
    }
    func getPost(id: String) async throws -> PostDetail {
        PostDetail(id: id, title: "A", content: "x", voteCount: 1, statusId: nil, boardId: "b1", createdAt: .init(), hasVoted: false)
    }
    func listComments(postId: String) async throws -> [Comment] { [] }
    func listBoards() async throws -> [Board] { [] }
    func listChangelog(cursor: String?) async throws -> Page<ChangelogEntry> { Page(data: [], meta: nil) }
    func listHelpCategories() async throws -> [HelpCategory] { [] }
    func getHelpArticle(slug: String) async throws -> HelpArticle {
        HelpArticle(id: "a", slug: slug, title: "T", content: "c", categoryId: "cat")
    }
    func submitPost(boardId: String, title: String, content: String) async throws -> PostSummary {
        if shouldUnauthorize { throw APIError.unauthorized }
        submitted = (boardId, title, content)
        return PostSummary(id: "post_new", title: title, voteCount: 0, statusId: nil, boardId: boardId, createdAt: .init(), hasVoted: false)
    }
    func vote(postId: String) async throws -> VoteResult {
        if shouldUnauthorize { throw APIError.unauthorized }
        return voteResult
    }
    func addComment(postId: String, content: String, parentId: String?) async throws -> Comment {
        if shouldUnauthorize { throw APIError.unauthorized }
        return Comment(id: "c1", content: content, authorName: "Me", createdAt: .init(), replies: [])
    }
}

func _mockConforms() -> FeedbackAPI { MockFeedbackAPI() }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter FeedbackKitTests`
Expected: FAIL — `FeedbackAPI`/`APIError`/`PostSort` undefined.

- [ ] **Step 3: Write minimal implementation**

```swift
// Sources/FeedbackKit/API/APIError.swift
import Foundation

public enum APIError: Error, Equatable, Sendable {
    case unauthorized
    case notFound
    case rateLimited
    case server(status: Int, code: String?)
    case transport(String)
    case decoding(String)
}
```

```swift
// Sources/FeedbackKit/API/FeedbackAPI.swift
import Foundation

public enum PostSort: String, Sendable { case newest, votes }

/// All public-API operations the app needs. View models depend on this, never URLSession.
public protocol FeedbackAPI: Sendable {
    // Reads (anonymous OK)
    func listPosts(boardId: String?, sort: PostSort, cursor: String?) async throws -> Page<PostSummary>
    func getPost(id: String) async throws -> PostDetail
    func listComments(postId: String) async throws -> [Comment]
    func listBoards() async throws -> [Board]
    func listChangelog(cursor: String?) async throws -> Page<ChangelogEntry>
    func listHelpCategories() async throws -> [HelpCategory]
    func getHelpArticle(slug: String) async throws -> HelpArticle
    // Writes (auth required → throw .unauthorized when no/expired token)
    func submitPost(boardId: String, title: String, content: String) async throws -> PostSummary
    func vote(postId: String) async throws -> VoteResult
    func addComment(postId: String, content: String, parentId: String?) async throws -> Comment
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter FeedbackKitTests`
Expected: PASS (mock compiles & conforms).

- [ ] **Step 5: Commit**

```bash
git add Sources/FeedbackKit/API/FeedbackAPI.swift Sources/FeedbackKit/API/APIError.swift Tests/FeedbackKitTests/MockFeedbackAPI.swift
git commit -m "feat(app): FeedbackAPI protocol + APIError + test mock"
```

---

## Task 4: `TokenStore` (bearer token persistence)

**Files:**
- Create: `Sources/FeedbackKit/Auth/TokenStore.swift`
- Test: `Tests/FeedbackKitTests/TokenStoreTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import FeedbackKit

final class TokenStoreTests: XCTestCase {
    func testInMemoryStoreRoundTrips() {
        let store = InMemoryTokenStore()
        XCTAssertNil(store.token)
        store.token = "abc"
        XCTAssertEqual(store.token, "abc")
        store.token = nil
        XCTAssertNil(store.token)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter TokenStoreTests`
Expected: FAIL — `InMemoryTokenStore` undefined.

- [ ] **Step 3: Write minimal implementation**

```swift
// Sources/FeedbackKit/Auth/TokenStore.swift
import Foundation

public protocol TokenStore: AnyObject, Sendable {
    var token: String? { get set }
}

/// Test/double store.
public final class InMemoryTokenStore: TokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var value: String?
    public init(token: String? = nil) { self.value = token }
    public var token: String? {
        get { lock.lock(); defer { lock.unlock() }; return value }
        set { lock.lock(); value = newValue; lock.unlock() }
    }
}

#if canImport(Security)
import Security

/// Keychain-backed store for the device.
public final class KeychainTokenStore: TokenStore, @unchecked Sendable {
    private let account: String
    private let service = "dev.opencoven.feedback.session"
    public init(account: String = "session-token") { self.account = account }

    public var token: String? {
        get {
            var query: [String: Any] = baseQuery
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            var item: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
                  let data = item as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        }
        set {
            SecItemDelete(baseQuery as CFDictionary)
            guard let newValue, let data = newValue.data(using: .utf8) else { return }
            var add = baseQuery
            add[kSecValueData as String] = data
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    private var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
}
#endif
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter TokenStoreTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/FeedbackKit/Auth/TokenStore.swift Tests/FeedbackKitTests/TokenStoreTests.swift
git commit -m "feat(app): TokenStore (in-memory + Keychain)"
```

---

## Task 5: `FeedViewModel` (anonymous read, the representative slice)

**Files:**
- Create: `Sources/FeedbackKit/Features/Feed/FeedViewModel.swift`
- Test: `Tests/FeedbackKitTests/FeedViewModelTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import FeedbackKit

@MainActor
final class FeedViewModelTests: XCTestCase {
    func testLoadPopulatesPostsAndClearsLoading() async {
        let api = MockFeedbackAPI()
        api.posts = [PostSummary(id: "post_1", title: "A", voteCount: 5, statusId: nil, boardId: "b1", createdAt: .init(), hasVoted: false)]
        let vm = FeedViewModel(api: api)
        await vm.load()
        XCTAssertEqual(vm.posts.map(\.id), ["post_1"])
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }

    func testLoadFailureSetsErrorMessage() async {
        final class FailingAPI: MockFeedbackAPI {
            override func listPosts(boardId: String?, sort: PostSort, cursor: String?) async throws -> Page<PostSummary> {
                throw APIError.transport("offline")
            }
        }
        let vm = FeedViewModel(api: FailingAPI())
        await vm.load()
        XCTAssertTrue(vm.posts.isEmpty)
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertFalse(vm.isLoading)
    }
}
```

> NOTE: `MockFeedbackAPI` methods must be `open`/overridable — mark the class `open` or its methods accordingly, or make `FailingAPI` a sibling mock. Simplest: change `MockFeedbackAPI` to a non-final class with overridable methods (drop `final`).

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter FeedViewModelTests`
Expected: FAIL — `FeedViewModel` undefined.

- [ ] **Step 3: Write minimal implementation**

```swift
// Sources/FeedbackKit/Features/Feed/FeedViewModel.swift
import Foundation

@MainActor
public final class FeedViewModel: ObservableObject {
    @Published public private(set) var posts: [PostSummary] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?

    private let api: FeedbackAPI
    public var boardId: String?
    public var sort: PostSort = .newest

    public init(api: FeedbackAPI) { self.api = api }

    public func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let page = try await api.listPosts(boardId: boardId, sort: sort, cursor: nil)
            posts = page.data
        } catch {
            errorMessage = Self.message(for: error)
        }
        isLoading = false
    }

    static func message(for error: Error) -> String {
        switch error {
        case APIError.transport: return "You appear to be offline. Pull to retry."
        case APIError.rateLimited: return "Too many requests. Try again shortly."
        default: return "Something went wrong. Please try again."
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter FeedViewModelTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/FeedbackKit/Features/Feed/FeedViewModel.swift Tests/FeedbackKitTests/FeedViewModelTests.swift Tests/FeedbackKitTests/MockFeedbackAPI.swift
git commit -m "feat(app): FeedViewModel with loading/error states"
```

---

## Task 6: `AuthStore` + email-OTP flow

**Files:**
- Create: `Sources/FeedbackKit/Auth/AuthStore.swift`
- Test: `Tests/FeedbackKitTests/AuthStoreTests.swift`

The email-OTP flow calls better-auth's existing endpoints: `POST /api/auth/email-otp/send-verification-otp` then `POST /api/auth/sign-in/email-otp`, which returns a session token. Abstract this behind an `AuthService` protocol so the store is testable.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import FeedbackKit

final class StubAuthService: AuthService, @unchecked Sendable {
    var sentTo: String?
    var tokenToReturn = "session_tok"
    func sendOTP(email: String) async throws { sentTo = email }
    func verifyOTP(email: String, code: String) async throws -> String { tokenToReturn }
}

@MainActor
final class AuthStoreTests: XCTestCase {
    func testSignInStoresTokenAndFlipsState() async {
        let store = InMemoryTokenStore()
        let auth = AuthStore(service: StubAuthService(), tokenStore: store)
        XCTAssertFalse(auth.isSignedIn)
        try? await auth.requestCode(email: "v@x.com")
        await auth.verify(email: "v@x.com", code: "123456")
        XCTAssertTrue(auth.isSignedIn)
        XCTAssertEqual(store.token, "session_tok")
    }

    func testSignOutClearsToken() async {
        let store = InMemoryTokenStore(token: "old")
        let auth = AuthStore(service: StubAuthService(), tokenStore: store)
        XCTAssertTrue(auth.isSignedIn)
        auth.signOut()
        XCTAssertFalse(auth.isSignedIn)
        XCTAssertNil(store.token)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter AuthStoreTests`
Expected: FAIL — `AuthService`/`AuthStore` undefined.

- [ ] **Step 3: Write minimal implementation**

```swift
// Sources/FeedbackKit/Auth/AuthStore.swift
import Foundation

public protocol AuthService: Sendable {
    func sendOTP(email: String) async throws
    func verifyOTP(email: String, code: String) async throws -> String  // returns session token
}

@MainActor
public final class AuthStore: ObservableObject {
    @Published public private(set) var isSignedIn: Bool
    @Published public private(set) var errorMessage: String?

    private let service: AuthService
    private let tokenStore: TokenStore

    public init(service: AuthService, tokenStore: TokenStore) {
        self.service = service
        self.tokenStore = tokenStore
        self.isSignedIn = tokenStore.token != nil
    }

    public var token: String? { tokenStore.token }

    public func requestCode(email: String) async throws {
        try await service.sendOTP(email: email)
    }

    public func verify(email: String, code: String) async {
        errorMessage = nil
        do {
            let token = try await service.verifyOTP(email: email, code: code)
            tokenStore.token = token
            isSignedIn = true
        } catch {
            errorMessage = "That code didn't work. Try again."
            isSignedIn = false
        }
    }

    public func signOut() {
        tokenStore.token = nil
        isSignedIn = false
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter AuthStoreTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/FeedbackKit/Auth/AuthStore.swift Tests/FeedbackKitTests/AuthStoreTests.swift
git commit -m "feat(app): AuthStore + email-OTP AuthService protocol"
```

---

## Task 7: `PostDetailViewModel` (detail + comments + vote with auth gating)

**Files:**
- Create: `Sources/FeedbackKit/Features/Detail/PostDetailViewModel.swift`
- Test: `Tests/FeedbackKitTests/PostDetailViewModelTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import FeedbackKit

@MainActor
final class PostDetailViewModelTests: XCTestCase {
    func testLoadFetchesPostAndComments() async {
        let api = MockFeedbackAPI()
        let vm = PostDetailViewModel(postId: "post_1", api: api, isSignedIn: { true })
        await vm.load()
        XCTAssertEqual(vm.post?.id, "post_1")
        XCTAssertNotNil(vm.comments)
    }

    func testVoteUpdatesCountWhenSignedIn() async {
        let api = MockFeedbackAPI()
        api.voteResult = VoteResult(voted: true, voteCount: 9)
        let vm = PostDetailViewModel(postId: "post_1", api: api, isSignedIn: { true })
        await vm.load()
        await vm.toggleVote()
        XCTAssertEqual(vm.post?.voteCount, 9)
        XCTAssertEqual(vm.post?.hasVoted, true)
        XCTAssertFalse(vm.needsSignIn)
    }

    func testVoteWhenSignedOutRequestsSignIn() async {
        let vm = PostDetailViewModel(postId: "post_1", api: MockFeedbackAPI(), isSignedIn: { false })
        await vm.load()
        await vm.toggleVote()
        XCTAssertTrue(vm.needsSignIn)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter PostDetailViewModelTests`
Expected: FAIL — `PostDetailViewModel` undefined.

- [ ] **Step 3: Write minimal implementation**

```swift
// Sources/FeedbackKit/Features/Detail/PostDetailViewModel.swift
import Foundation

@MainActor
public final class PostDetailViewModel: ObservableObject {
    @Published public private(set) var post: PostDetail?
    @Published public private(set) var comments: [Comment] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    @Published public var needsSignIn = false

    private let postId: String
    private let api: FeedbackAPI
    private let isSignedIn: () -> Bool

    public init(postId: String, api: FeedbackAPI, isSignedIn: @escaping () -> Bool) {
        self.postId = postId
        self.api = api
        self.isSignedIn = isSignedIn
    }

    public func load() async {
        isLoading = true; errorMessage = nil
        do {
            async let p = api.getPost(id: postId)
            async let c = api.listComments(postId: postId)
            post = try await p
            comments = try await c
        } catch {
            errorMessage = FeedViewModel.message(for: error)
        }
        isLoading = false
    }

    public func toggleVote() async {
        guard isSignedIn() else { needsSignIn = true; return }
        do {
            let result = try await api.vote(postId: postId)
            if var current = post {
                post = PostDetail(id: current.id, title: current.title, content: current.content,
                                  voteCount: result.voteCount, statusId: current.statusId,
                                  boardId: current.boardId, createdAt: current.createdAt, hasVoted: result.voted)
                _ = current
            }
        } catch APIError.unauthorized {
            needsSignIn = true
        } catch {
            errorMessage = FeedViewModel.message(for: error)
        }
    }

    public func addComment(_ text: String) async {
        guard isSignedIn() else { needsSignIn = true; return }
        do {
            let comment = try await api.addComment(postId: postId, content: text, parentId: nil)
            comments.insert(comment, at: 0)
        } catch APIError.unauthorized {
            needsSignIn = true
        } catch {
            errorMessage = FeedViewModel.message(for: error)
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter PostDetailViewModelTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/FeedbackKit/Features/Detail/PostDetailViewModel.swift Tests/FeedbackKitTests/PostDetailViewModelTests.swift
git commit -m "feat(app): PostDetailViewModel (vote/comment with sign-in gate)"
```

---

## Task 8: `SubmitViewModel` (auth-gated write)

**Files:**
- Create: `Sources/FeedbackKit/Features/Submit/SubmitViewModel.swift`
- Test: `Tests/FeedbackKitTests/SubmitViewModelTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import FeedbackKit

@MainActor
final class SubmitViewModelTests: XCTestCase {
    func testSubmitSucceedsWhenSignedIn() async {
        let api = MockFeedbackAPI()
        let vm = SubmitViewModel(api: api, isSignedIn: { true })
        vm.boardId = "b1"; vm.title = "Bug"; vm.content = "Crashes on launch"
        let ok = await vm.submit()
        XCTAssertTrue(ok)
        XCTAssertEqual(api.submitted?.title, "Bug")
    }
    func testSubmitBlockedWhenSignedOut() async {
        let vm = SubmitViewModel(api: MockFeedbackAPI(), isSignedIn: { false })
        vm.boardId = "b1"; vm.title = "Bug"
        let ok = await vm.submit()
        XCTAssertFalse(ok)
        XCTAssertTrue(vm.needsSignIn)
    }
    func testSubmitValidatesEmptyTitle() async {
        let vm = SubmitViewModel(api: MockFeedbackAPI(), isSignedIn: { true })
        vm.boardId = "b1"; vm.title = "  "
        let ok = await vm.submit()
        XCTAssertFalse(ok)
        XCTAssertEqual(vm.errorMessage, "Title is required.")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter SubmitViewModelTests`
Expected: FAIL — `SubmitViewModel` undefined.

- [ ] **Step 3: Write minimal implementation**

```swift
// Sources/FeedbackKit/Features/Submit/SubmitViewModel.swift
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter SubmitViewModelTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/FeedbackKit/Features/Submit/SubmitViewModel.swift Tests/FeedbackKitTests/SubmitViewModelTests.swift
git commit -m "feat(app): SubmitViewModel (validation + sign-in gate)"
```

---

## Task 9: `ChangelogViewModel` and `HelpViewModel` (read-only)

**Files:**
- Create: `Sources/FeedbackKit/Features/Changelog/ChangelogViewModel.swift`, `Sources/FeedbackKit/Features/Help/HelpViewModel.swift`
- Test: `Tests/FeedbackKitTests/ReadOnlyViewModelsTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import FeedbackKit

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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ReadOnlyViewModelsTests`
Expected: FAIL — view models undefined.

- [ ] **Step 3: Write minimal implementation**

```swift
// Sources/FeedbackKit/Features/Changelog/ChangelogViewModel.swift
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
```

```swift
// Sources/FeedbackKit/Features/Help/HelpViewModel.swift
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter ReadOnlyViewModelsTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/FeedbackKit/Features/Changelog Sources/FeedbackKit/Features/Help Tests/FeedbackKitTests/ReadOnlyViewModelsTests.swift
git commit -m "feat(app): Changelog + Help view models"
```

---

## Task 10: `HTTPFeedbackAPI` (URLSession implementation)

**Files:**
- Create: `Sources/FeedbackKit/API/HTTPFeedbackAPI.swift`, `Sources/FeedbackKit/Config/AppConfig.swift`
- Test: `Tests/FeedbackKitTests/HTTPFeedbackAPITests.swift` (uses `URLProtocol` stub)

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import FeedbackKit

final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for r: URLRequest) -> URLRequest { r }
    override func startLoading() {
        let (resp, data) = StubURLProtocol.handler!(request)
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class HTTPFeedbackAPITests: XCTestCase {
    private func makeAPI(token: String? = nil) -> HTTPFeedbackAPI {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: cfg)
        return HTTPFeedbackAPI(baseURL: URL(string: "https://fb.example.com")!,
                               session: session, tokenProvider: { token })
    }

    func testListPostsParsesEnvelope() async throws {
        StubURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/api/public/v1/posts")
            let body = #"{"data":[{"id":"post_1","title":"A","voteCount":2,"statusId":null,"boardId":"b1","createdAt":"2026-01-01T00:00:00.000Z","hasVoted":false}],"meta":{"pagination":{"cursor":null,"hasMore":false}}}"#
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body.data(using: .utf8)!)
        }
        let page = try await makeAPI().listPosts(boardId: nil, sort: .newest, cursor: nil)
        XCTAssertEqual(page.data.first?.id, "post_1")
    }

    func testVoteSendsBearerAndMapsUnauthorized() async {
        StubURLProtocol.handler = { req in
            XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer tok")
            return (HTTPURLResponse(url: req.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!,
                    #"{"error":{"code":"UNAUTHORIZED","message":"x"}}"#.data(using: .utf8)!)
        }
        do { _ = try await makeAPI(token: "tok").vote(postId: "post_1"); XCTFail("expected throw") }
        catch { XCTAssertEqual(error as? APIError, .unauthorized) }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter HTTPFeedbackAPITests`
Expected: FAIL — `HTTPFeedbackAPI` undefined.

- [ ] **Step 3: Write minimal implementation**

```swift
// Sources/FeedbackKit/Config/AppConfig.swift
import Foundation
public struct AppConfig: Sendable {
    public let instanceURL: URL
    public init(instanceURL: URL) { self.instanceURL = instanceURL }
}
```

```swift
// Sources/FeedbackKit/API/HTTPFeedbackAPI.swift
import Foundation

public final class HTTPFeedbackAPI: FeedbackAPI, @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let tokenProvider: @Sendable () -> String?

    public init(baseURL: URL, session: URLSession = .shared, tokenProvider: @escaping @Sendable () -> String?) {
        self.baseURL = baseURL; self.session = session; self.tokenProvider = tokenProvider
    }

    // MARK: Reads
    public func listPosts(boardId: String?, sort: PostSort, cursor: String?) async throws -> Page<PostSummary> {
        var q = [URLQueryItem(name: "sort", value: sort.rawValue)]
        if let boardId { q.append(.init(name: "boardId", value: boardId)) }
        if let cursor { q.append(.init(name: "cursor", value: cursor)) }
        return try await get("/api/public/v1/posts", query: q)
    }
    public func getPost(id: String) async throws -> PostDetail {
        try await getEnvelope("/api/public/v1/posts/\(id)")
    }
    public func listComments(postId: String) async throws -> [Comment] {
        try await getEnvelope("/api/public/v1/posts/\(postId)/comments")
    }
    public func listBoards() async throws -> [Board] { try await getEnvelope("/api/public/v1/boards") }
    public func listChangelog(cursor: String?) async throws -> Page<ChangelogEntry> {
        try await get("/api/public/v1/changelog", query: cursor.map { [URLQueryItem(name: "cursor", value: $0)] } ?? [])
    }
    public func listHelpCategories() async throws -> [HelpCategory] { try await getEnvelope("/api/public/v1/help/categories") }
    public func getHelpArticle(slug: String) async throws -> HelpArticle { try await getEnvelope("/api/public/v1/help/articles/\(slug)") }

    // MARK: Writes
    public func submitPost(boardId: String, title: String, content: String) async throws -> PostSummary {
        try await postEnvelope("/api/public/v1/posts", body: ["boardId": boardId, "title": title, "content": content])
    }
    public func vote(postId: String) async throws -> VoteResult {
        try await postEnvelope("/api/public/v1/posts/\(postId)/vote", body: [:])
    }
    public func addComment(postId: String, content: String, parentId: String?) async throws -> Comment {
        var body: [String: String] = ["content": content]
        if let parentId { body["parentId"] = parentId }
        return try await postEnvelope("/api/public/v1/posts/\(postId)/comments", body: body)
    }

    // MARK: Transport
    private func get<T: Codable & Sendable & Equatable>(_ path: String, query: [URLQueryItem]) async throws -> Page<T> {
        try await send(request(path, method: "GET", query: query))
    }
    private func getEnvelope<T: Codable & Sendable & Equatable>(_ path: String) async throws -> T {
        let env: Envelope<T> = try await send(request(path, method: "GET", query: []))
        return env.data
    }
    private func postEnvelope<T: Codable & Sendable & Equatable>(_ path: String, body: [String: String]) async throws -> T {
        var req = request(path, method: "POST", query: [])
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let env: Envelope<T> = try await send(req)
        return env.data
    }

    private func request(_ path: String, method: String, query: [URLQueryItem]) -> URLRequest {
        var comps = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { comps.queryItems = query }
        var req = URLRequest(url: comps.url!)
        req.httpMethod = method
        if let token = tokenProvider() { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return req
    }

    private func send<R: Decodable>(_ req: URLRequest) async throws -> R {
        let (data, response): (Data, URLResponse)
        do { (data, response) = try await session.data(for: req) }
        catch { throw APIError.transport(error.localizedDescription) }
        guard let http = response as? HTTPURLResponse else { throw APIError.transport("No HTTP response") }
        switch http.statusCode {
        case 200..<300: break
        case 401: throw APIError.unauthorized
        case 404: throw APIError.notFound
        case 429: throw APIError.rateLimited
        default: throw APIError.server(status: http.statusCode, code: Self.errorCode(data))
        }
        do { return try JSONDecoder.feedback.decode(R.self, from: data) }
        catch { throw APIError.decoding(String(describing: error)) }
    }

    private static func errorCode(_ data: Data) -> String? {
        struct E: Decodable { struct Inner: Decodable { let code: String }; let error: Inner }
        return (try? JSONDecoder().decode(E.self, from: data))?.error.code
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter HTTPFeedbackAPITests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/FeedbackKit/API/HTTPFeedbackAPI.swift Sources/FeedbackKit/Config/AppConfig.swift Tests/FeedbackKitTests/HTTPFeedbackAPITests.swift
git commit -m "feat(app): HTTPFeedbackAPI URLSession client (bearer + error mapping)"
```

---

## Task 11: `HTTPAuthService` (better-auth email-OTP over HTTP)

**Files:**
- Create: `Sources/FeedbackKit/Auth/HTTPAuthService.swift`
- Test: `Tests/FeedbackKitTests/HTTPAuthServiceTests.swift` (reuses `StubURLProtocol`)

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import FeedbackKit

final class HTTPAuthServiceTests: XCTestCase {
    private func make() -> HTTPAuthService {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [StubURLProtocol.self]
        return HTTPAuthService(baseURL: URL(string: "https://fb.example.com")!, session: URLSession(configuration: cfg))
    }
    func testVerifyReturnsToken() async throws {
        StubURLProtocol.handler = { req in
            XCTAssertEqual(req.url?.path, "/api/auth/sign-in/email-otp")
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    #"{"token":"sess_123","user":{"id":"u1"}}"#.data(using: .utf8)!)
        }
        let token = try await make().verifyOTP(email: "v@x.com", code: "123456")
        XCTAssertEqual(token, "sess_123")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter HTTPAuthServiceTests`
Expected: FAIL — `HTTPAuthService` undefined.

- [ ] **Step 3: Write minimal implementation**

```swift
// Sources/FeedbackKit/Auth/HTTPAuthService.swift
import Foundation

public final class HTTPAuthService: AuthService, @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession
    public init(baseURL: URL, session: URLSession = .shared) { self.baseURL = baseURL; self.session = session }

    public func sendOTP(email: String) async throws {
        _ = try await post("/api/auth/email-otp/send-verification-otp", body: ["email": email, "type": "sign-in"])
    }

    public func verifyOTP(email: String, code: String) async throws -> String {
        let data = try await post("/api/auth/sign-in/email-otp", body: ["email": email, "otp": code])
        struct R: Decodable { let token: String }
        guard let token = try? JSONDecoder().decode(R.self, from: data).token else {
            throw APIError.decoding("No token in sign-in response")
        }
        return token
    }

    private func post(_ path: String, body: [String: String]) async throws -> Data {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.server(status: (response as? HTTPURLResponse)?.statusCode ?? -1, code: nil)
        }
        return data
    }
}
```

> NOTE: Confirm the exact better-auth email-OTP endpoint paths and the field names (`email`/`otp`/`type`) and the token property in the response against the running instance (`/api/auth/*` — better-auth `emailOTP` plugin). Adjust paths/keys to match; the protocol (`AuthService`) and `AuthStore` (Task 6) do not change.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter HTTPAuthServiceTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/FeedbackKit/Auth/HTTPAuthService.swift Tests/FeedbackKitTests/HTTPAuthServiceTests.swift
git commit -m "feat(app): HTTPAuthService (better-auth email-OTP)"
```

---

## Task 12: SwiftUI app target — 4-tab shell + screens

**Files:**
- Create: `App/FeedbackPortalApp/FeedbackPortalApp.swift`, `RootTabView.swift`, `FeedTabView.swift`, `PostDetailView.swift`, `SubmitView.swift`, `ChangelogTabView.swift`, `HelpTabView.swift`, `AccountTabView.swift`, `SignInSheet.swift`, `Environment.swift`
- Modify: `App/project.yml` (new XcodeGen target `FeedbackPortalApp` depending on `FeedbackKit`) — or add to the existing `project.yml`.

This task is UI wiring; it is verified by the CI build (Task 13), not unit tests. Build incrementally and run the app in the simulator.

- [ ] **Step 1: Composition root**

```swift
// App/FeedbackPortalApp/Environment.swift
import FeedbackKit
import SwiftUI

@MainActor
final class AppEnvironment: ObservableObject {
    let api: FeedbackAPI
    let auth: AuthStore
    init() {
        let url = URL(string: Bundle.main.object(forInfoDictionaryKey: "FEEDBACK_INSTANCE_URL") as? String ?? "http://localhost:3000")!
        let tokenStore: TokenStore = KeychainTokenStore()
        self.auth = AuthStore(service: HTTPAuthService(baseURL: url), tokenStore: tokenStore)
        self.api = HTTPFeedbackAPI(baseURL: url, tokenProvider: { tokenStore.token })
    }
}
```

```swift
// App/FeedbackPortalApp/FeedbackPortalApp.swift
import SwiftUI

@main
struct FeedbackPortalApp: App {
    @StateObject private var env = AppEnvironment()
    var body: some Scene {
        WindowGroup { RootTabView().environmentObject(env).environmentObject(env.auth) }
    }
}
```

- [ ] **Step 2: 4-tab shell**

```swift
// App/FeedbackPortalApp/RootTabView.swift
import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            FeedTabView().tabItem { Label("Feedback", systemImage: "bubble.left.and.bubble.right") }
            ChangelogTabView().tabItem { Label("Changelog", systemImage: "sparkles") }
            HelpTabView().tabItem { Label("Help", systemImage: "questionmark.circle") }
            AccountTabView().tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
    }
}
```

- [ ] **Step 3: Feed tab (list → detail → submit)**

```swift
// App/FeedbackPortalApp/FeedTabView.swift
import FeedbackKit
import SwiftUI

struct FeedTabView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var vm: FeedViewModel
    @State private var showSubmit = false

    init() { _vm = StateObject(wrappedValue: FeedViewModel(api: AppEnvironment().api)) }

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.posts.isEmpty { ProgressView() }
                else if let err = vm.errorMessage, vm.posts.isEmpty {
                    ContentUnavailableView("Couldn't load", systemImage: "wifi.slash", description: Text(err))
                } else {
                    List(vm.posts) { post in
                        NavigationLink(value: post.id) {
                            HStack { Text("\(post.voteCount)").monospacedDigit().frame(width: 36); Text(post.title) }
                        }
                    }
                    .refreshable { await vm.load() }
                }
            }
            .navigationTitle("Feedback")
            .toolbar { ToolbarItem(placement: .primaryAction) { Button { showSubmit = true } label: { Image(systemName: "plus") } } }
            .navigationDestination(for: String.self) { PostDetailView(postId: $0) }
            .sheet(isPresented: $showSubmit) { SubmitView() }
            .task { await vm.load() }
        }
    }
}
```

> NOTE: The `init()` above constructs a throwaway `AppEnvironment` just to obtain `api` because `@StateObject` can't read `@EnvironmentObject` at init. Cleaner: make `FeedViewModel` lazily settable and inject `env.api` in `.task`, or pass `api` down from `RootTabView`. Pick one pattern and use it consistently for all tabs. The remaining screens (`PostDetailView`, `SubmitView`, `ChangelogTabView`, `HelpTabView`, `AccountTabView`, `SignInSheet`) follow the same shape: bind a `@StateObject` view model, render loading/error/empty/content, and present `SignInSheet` when the view model's `needsSignIn` flips true. `SignInSheet` collects an email, calls `auth.requestCode`, then a 6-digit code calling `auth.verify`.

- [ ] **Step 4: Build & run in the simulator**

Run: open the generated project and run `FeedbackPortalApp` on an iOS Simulator. Verify: feed loads (anonymous), tapping a post shows detail, voting/commenting/submitting prompts sign-in when signed out, changelog and help load.
Expected: golden-path flows work against a live/staging instance.

- [ ] **Step 5: Commit**

```bash
git add App/FeedbackPortalApp App/project.yml
git commit -m "feat(app): SwiftUI 4-tab shell + screens"
```

---

## Task 13: Offline content cache

**Files:**
- Create: `Sources/FeedbackKit/Cache/ContentCache.swift`
- Test: `Tests/FeedbackKitTests/ContentCacheTests.swift`
- Modify: `FeedViewModel`, `ChangelogViewModel`, `HelpViewModel` to read cache on failure / seed before load.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import FeedbackKit

final class ContentCacheTests: XCTestCase {
    func testRoundTripsPosts() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cache = ContentCache(directory: dir)
        let posts = [PostSummary(id: "post_1", title: "A", voteCount: 1, statusId: nil, boardId: "b1", createdAt: .init(), hasVoted: false)]
        try cache.save(posts, as: "feed")
        let loaded: [PostSummary] = try cache.load("feed", as: [PostSummary].self)
        XCTAssertEqual(loaded, posts)
    }

    func testLoadMissingThrows() {
        let cache = ContentCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        XCTAssertThrowsError(try cache.load("nope", as: [PostSummary].self))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ContentCacheTests`
Expected: FAIL — `ContentCache` undefined.

- [ ] **Step 3: Write minimal implementation**

```swift
// Sources/FeedbackKit/Cache/ContentCache.swift
import Foundation

public struct ContentCache: Sendable {
    private let directory: URL
    public init(directory: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("FeedbackKit")) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    public func save<T: Encodable>(_ value: T, as key: String) throws {
        let data = try JSONEncoder().encode(value)
        try data.write(to: directory.appendingPathComponent("\(key).json"), options: .atomic)
    }
    public func load<T: Decodable>(_ key: String, as type: T.Type) throws -> T {
        let data = try Data(contentsOf: directory.appendingPathComponent("\(key).json"))
        return try JSONDecoder.feedback.decode(T.self, from: data)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter ContentCacheTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Wire into FeedViewModel and commit**

In `FeedViewModel.load()`: after a successful fetch, `try? cache.save(posts, as: "feed")`; in the `catch`, if `posts.isEmpty`, attempt `posts = (try? cache.load("feed", as: [PostSummary].self)) ?? []` and only show the error if the cache is also empty. Add a `cache` init parameter defaulting to `ContentCache()`. Repeat for Changelog/Help.

```bash
git add Sources/FeedbackKit/Cache/ContentCache.swift Tests/FeedbackKitTests/ContentCacheTests.swift Sources/FeedbackKit/Features
git commit -m "feat(app): offline content cache (read-only fallback)"
```

---

## Task 14: CI — build the app for iOS + run FeedbackKit tests

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Add FeedbackKit to the iOS build job**

The existing `ios-build` job runs `xcodebuild -scheme OpenCovenFeedback -destination 'generic/platform=iOS Simulator'`. Add a second build of the app:

```yaml
      - name: Build FeedbackPortalApp (iOS Simulator)
        run: |
          brew install xcodegen
          (cd App && xcodegen generate)
          xcodebuild build \
            -project App/FeedbackPortalApp.xcodeproj \
            -scheme FeedbackPortalApp \
            -sdk iphonesimulator \
            -destination 'generic/platform=iOS Simulator' \
            CODE_SIGNING_ALLOWED=NO
```

> NOTE: Pin a `schemes:` entry for `FeedbackPortalApp` in `App/project.yml` (XcodeGen does not emit shared schemes by default — this was the cause of an earlier CI failure on the SDK side). If XcodeGen's project-format version outruns the runner's Xcode (objectVersion mismatch — also hit earlier), prefer building the SPM `FeedbackKit` library for iOS via `xcodebuild -scheme FeedbackKit -destination 'generic/platform=iOS Simulator'` and keep the app build behind a newer-Xcode runner (`macos-15`).

- [ ] **Step 2: Confirm `swift test` covers FeedbackKit**

The `test` job already runs `swift test`; with `FeedbackKit` added to `Package.swift` (Task 1) it now includes all FeedbackKit tests. No change needed beyond verifying locally:

Run: `swift test`
Expected: all `OpenCovenFeedback*` and `FeedbackKit*` tests PASS.

- [ ] **Step 3: Commit + push + PR**

```bash
git add .github/workflows/ci.yml App/project.yml
git commit -m "ci: build FeedbackPortalApp + run FeedbackKit tests"
git push -u origin feat/native-give-feedback-app
gh pr create --repo OpenCoven/feedback-mobile --base main \
  --title "feat: native give-feedback iOS app (FeedbackKit + FeedbackPortalApp)" \
  --body "Native SwiftUI app over the Track 1 public API: feed, post detail, vote, comment, submit, changelog, help. Email-OTP bearer auth, offline read cache. Requires Track 1 (/api/public/v1)."
```

---

## Self-Review

- **Spec coverage** (design §5): API client ✅ T3/T10 · email-OTP bearer auth ✅ T6/T11 + Keychain T4 · Feedback (feed/detail/vote/comment/submit) ✅ T5/T7/T8 · Changelog ✅ T9 · Help ✅ T9 · Account (sign-in/out) ✅ T6 + SignInSheet T12 · offline cache ✅ T13 · 4-tab nav ✅ T12 · CI ✅ T14. `hasVoted` enrichment flows from API (T2 model) through detail VM (T7).
- **Placeholder scan:** No "TBD"/"handle later". The `> NOTE:` blocks are concrete verify/choose instructions (exact better-auth paths, the SwiftUI injection pattern, the XcodeGen scheme/objectVersion gotcha learned earlier) — not vague filler. Task 12 is explicitly UI-wiring verified by CI/simulator rather than unit tests, and names every screen file.
- **Type consistency:** `FeedbackAPI` (T3) is the exact surface implemented by `HTTPFeedbackAPI` (T10) and `MockFeedbackAPI` (T3) and consumed by every view model. `FeedViewModel.message(for:)` (T5) is reused by the detail/submit/changelog/help VMs. `AuthService` (T6) is implemented by `HTTPAuthService` (T11). `TokenStore` (T4) feeds both `AuthStore` (T6) and `HTTPFeedbackAPI.tokenProvider` (T10/T12).
- **Dependency on Track 1:** view models test against the mock, so this plan is executable before the live API exists; the HTTP client/auth-service NOTE blocks flag the fields to confirm against the running instance.
