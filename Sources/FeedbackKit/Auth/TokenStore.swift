import Foundation
#if canImport(Security)
import Security
#endif

// MARK: - Protocol

public protocol TokenStore: AnyObject, Sendable {
    var token: String? { get set }
}

// MARK: - InMemoryTokenStore

public final class InMemoryTokenStore: TokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var _token: String?

    public init(token: String? = nil) {
        _token = token
    }

    public var token: String? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _token
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _token = newValue
        }
    }
}

// MARK: - KeychainTokenStore

#if canImport(Security)
public final class KeychainTokenStore: TokenStore, @unchecked Sendable {
    private let service: String
    private let account: String

    public init(
        service: String = "dev.opencoven.feedback.session",
        account: String = "session-token"
    ) {
        self.service = service
        self.account = account
    }

    private var baseQuery: [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
    }

    public var token: String? {
        get {
            var query = baseQuery
            query[kSecReturnData] = kCFBooleanTrue
            query[kSecMatchLimit] = kSecMatchLimitOne

            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            guard status == errSecSuccess, let data = result as? Data else {
                return nil
            }
            return String(data: data, encoding: .utf8)
        }
        set {
            SecItemDelete(baseQuery as CFDictionary)
            guard let value = newValue, let data = value.data(using: .utf8) else {
                return
            }
            var addQuery = baseQuery
            addQuery[kSecValueData] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }
}
#endif
