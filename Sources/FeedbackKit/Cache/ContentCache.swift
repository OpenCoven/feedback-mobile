import Foundation

public struct ContentCache: Sendable {
    private let directory: URL

    public init(directory: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("FeedbackKit")) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func save<T: Encodable>(_ value: T, as key: String) throws {
        let data = try Self.encoder.encode(value)
        try data.write(to: directory.appendingPathComponent("\(key).json"), options: .atomic)
    }

    public func load<T: Decodable>(_ key: String, as type: T.Type) throws -> T {
        let data = try Data(contentsOf: directory.appendingPathComponent("\(key).json"))
        return try JSONDecoder.feedback.decode(T.self, from: data)
    }

    // Encoder whose date strategy matches JSONDecoder.feedback (ISO-8601 with fractional seconds).
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        encoder.dateEncodingStrategy = .custom { date, enc in
            var container = enc.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        return encoder
    }()
}
