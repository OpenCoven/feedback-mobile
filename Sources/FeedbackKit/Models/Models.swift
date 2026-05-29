import Foundation

// MARK: - Envelope types

public struct Envelope<T: Codable & Sendable & Equatable>: Codable, Sendable, Equatable {
    public let data: T

    public init(data: T) {
        self.data = data
    }
}

public struct Pagination: Codable, Sendable, Equatable {
    public let cursor: String?
    public let hasMore: Bool

    public init(cursor: String?, hasMore: Bool) {
        self.cursor = cursor
        self.hasMore = hasMore
    }
}

public struct Meta: Codable, Sendable, Equatable {
    public let pagination: Pagination?

    public init(pagination: Pagination?) {
        self.pagination = pagination
    }
}

public struct Page<T: Codable & Sendable & Equatable>: Codable, Sendable, Equatable {
    public let data: [T]
    public let meta: Meta?

    public init(data: [T], meta: Meta?) {
        self.data = data
        self.meta = meta
    }
}

// MARK: - Domain models

public struct Board: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let slug: String
    public let description: String?
    public let postCount: Int?

    public init(id: String, name: String, slug: String, description: String?, postCount: Int?) {
        self.id = id
        self.name = name
        self.slug = slug
        self.description = description
        self.postCount = postCount
    }
}

public struct PostSummary: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let voteCount: Int
    public let statusId: String?
    public let boardId: String
    public let createdAt: Date
    public let hasVoted: Bool

    public init(id: String, title: String, voteCount: Int, statusId: String?, boardId: String, createdAt: Date, hasVoted: Bool) {
        self.id = id
        self.title = title
        self.voteCount = voteCount
        self.statusId = statusId
        self.boardId = boardId
        self.createdAt = createdAt
        self.hasVoted = hasVoted
    }
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

    public init(id: String, title: String, content: String, voteCount: Int, statusId: String?, boardId: String, createdAt: Date, hasVoted: Bool) {
        self.id = id
        self.title = title
        self.content = content
        self.voteCount = voteCount
        self.statusId = statusId
        self.boardId = boardId
        self.createdAt = createdAt
        self.hasVoted = hasVoted
    }
}

public struct Comment: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let content: String
    public let authorName: String
    public let createdAt: Date
    public let replies: [Comment]

    public init(id: String, content: String, authorName: String, createdAt: Date, replies: [Comment]) {
        self.id = id
        self.content = content
        self.authorName = authorName
        self.createdAt = createdAt
        self.replies = replies
    }
}

public struct ChangelogEntry: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let content: String?
    public let publishedAt: Date?

    public init(id: String, title: String, content: String?, publishedAt: Date?) {
        self.id = id
        self.title = title
        self.content = content
        self.publishedAt = publishedAt
    }
}

public struct HelpCategory: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let slug: String
    public let description: String?

    public init(id: String, name: String, slug: String, description: String?) {
        self.id = id
        self.name = name
        self.slug = slug
        self.description = description
    }
}

public struct HelpArticle: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let slug: String
    public let title: String
    public let content: String
    public let categoryId: String

    public init(id: String, slug: String, title: String, content: String, categoryId: String) {
        self.id = id
        self.slug = slug
        self.title = title
        self.content = content
        self.categoryId = categoryId
    }
}

public struct VoteResult: Codable, Sendable, Equatable {
    public let voted: Bool
    public let voteCount: Int

    public init(voted: Bool, voteCount: Int) {
        self.voted = voted
        self.voteCount = voteCount
    }
}

// MARK: - JSONDecoder extension

public extension JSONDecoder {
    static let feedback: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { dec in
            let container = try dec.singleValueContainer()
            let string = try container.decode(String.self)
            guard let date = formatter.date(from: string) else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: dec.codingPath,
                        debugDescription: "Invalid ISO-8601 date with fractional seconds: \(string)"
                    )
                )
            }
            return date
        }
        return decoder
    }()
}
