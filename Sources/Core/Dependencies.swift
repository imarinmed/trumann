import CryptoKit
import Dependencies
import Foundation
import OSLog

// MARK: - Clock Protocol

public protocol Clock: Sendable {
    var now: Date { get }
    func sleep(for duration: TimeInterval) async throws
}

extension Clock where Self == LiveClock {
    public static var live: Self { LiveClock() }
}

public struct LiveClock: Clock {
    public var now: Date { Date() }

    public func sleep(for duration: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
    }
}

extension Clock where Self == TestClock {
    public static func test(current: Date = Date()) -> Self {
        TestClock(current: current)
    }
}

public final class TestClock: Clock, @unchecked Sendable {
    public var current: Date
    private var _now: Date

    public init(current: Date = Date()) {
        self.current = current
        self._now = current
    }

    public var now: Date {
        get { _now }
        set { _now = newValue }
    }

    public func sleep(for duration: TimeInterval) async throws {
        _now = _now.addingTimeInterval(duration)
    }
}

// MARK: - UUID Generator Protocol

public protocol UUIDGenerator: Sendable {
    func uuid() -> UUID
}

extension UUIDGenerator where Self == LiveUUIDGenerator {
    public static var live: Self { LiveUUIDGenerator() }
}

public struct LiveUUIDGenerator: UUIDGenerator {
    public func uuid() -> UUID { UUID() }
}

extension UUIDGenerator where Self == TestUUIDGenerator {
    public static func test(uuids: [UUID] = []) -> Self {
        TestUUIDGenerator(uuids: uuids)
    }
}

public final class TestUUIDGenerator: UUIDGenerator, @unchecked Sendable {
    private var uuids: [UUID]
    private var index = 0

    public init(uuids: [UUID] = []) {
        self.uuids = uuids
    }

    public func uuid() -> UUID {
        defer { index += 1 }
        return uuids.indices.contains(index) ? uuids[index] : UUID()
    }
}

// MARK: - Logger Protocol

public protocol Logger: Sendable {
    func log(level: LogLevel, message: String, metadata: [String: String])
}

public enum LogLevel: String, Sendable {
    case debug, info, warning, error
}

extension Logger where Self == LiveLogger {
    public static var live: Self { LiveLogger() }
}

public struct LiveLogger: Logger {
    public func log(level: LogLevel, message: String, metadata: [String: String]) {
        // Redact sensitive data
        let redactedMessage = redact(message)
        let redactedMetadata = metadata.mapValues { redact($0) }

        // Use OSLog with .private for sensitive data
        os_log(
            .default,
            log: .default,
            "[%{public}@] %{private}@ %{private}@",
            level.rawValue.uppercased(),
            redactedMessage,
            redactedMetadata.description
        )
    }

    private func redact(_ string: String) -> String {
        // Basic redaction - replace potential PII patterns
        string
            .replacingOccurrences(of: #"\b\d{3}-\d{2}-\d{4}\b"#, with: "[REDACTED_SSN]", options: .regularExpression)
            .replacingOccurrences(of: #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b"#, with: "[REDACTED_EMAIL]", options: .regularExpression)
    }
}

extension Logger where Self == TestLogger {
    public static var test: Self { TestLogger() }
}

public final class TestLogger: Logger, @unchecked Sendable {
    public private(set) var logs: [(level: LogLevel, message: String, metadata: [String: String])] = []

    public func log(level: LogLevel, message: String, metadata: [String: String]) {
        logs.append((level, message, metadata))
    }
}

// MARK: - Storage Protocol

public protocol Storage: Sendable {
    func save<T: Encodable>(_ value: T, forKey key: String) async throws
    func load<T: Decodable>(_ type: T.Type, forKey key: String) async throws -> T?
    func delete(forKey key: String) async throws
}

extension Storage where Self == LiveStorage {
    public static var live: Self { LiveStorage() }
}

public final class LiveStorage: Storage, @unchecked Sendable {
    private let fileManager = FileManager.default
    private let lock = NSLock()
    private let encryptionKey: SymmetricKey

    private var cacheDirectory: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Trumann", isDirectory: true)
    }

    public init() {
        // Generate a persistent encryption key (in real app, derive from user credentials)
        let keyData = "TrumannStorageKey".data(using: .utf8)!
        encryptionKey = SymmetricKey(data: SHA256.hash(data: keyData))
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    public func save<T: Encodable>(_ value: T, forKey key: String) async throws {
        let url = cacheDirectory.appendingPathComponent(key)
        let data = try JSONEncoder().encode(value)
        let encryptedData: Data = try AES.GCM.seal(data, using: encryptionKey).combined!

        try lock.withLock {
            try encryptedData.write(to: url, options: .atomic)
        }

        // Set file protection outside lock
        let attributes: [FileAttributeKey: Any] = [
            .protectionKey: FileProtectionType.complete
        ]
        try fileManager.setAttributes(attributes, ofItemAtPath: url.path)
    }

    public func load<T: Decodable>(_ type: T.Type, forKey key: String) async throws -> T? {
        let url = cacheDirectory.appendingPathComponent(key)
        return try lock.withLock {
            let encryptedData = try Data(contentsOf: url)
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: encryptionKey)
            return try JSONDecoder().decode(T.self, from: decryptedData)
        }
    }

    public func delete(forKey key: String) async throws {
        let url = cacheDirectory.appendingPathComponent(key)
        try await withCheckedThrowingContinuation { continuation in
            lock.withLock {
                do {
                    try fileManager.removeItem(at: url)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

extension Storage where Self == TestStorage {
    public static var test: Self { TestStorage() }
}

public final class TestStorage: Storage, @unchecked Sendable {
    public var storage: [String: Data] = [:]

    public func save<T: Encodable>(_ value: T, forKey key: String) async throws {
        let data = try JSONEncoder().encode(value)
        storage[key] = data
    }

    public func load<T: Decodable>(_ type: T.Type, forKey key: String) async throws -> T? {
        guard let data = storage[key] else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }

    public func delete(forKey key: String) async throws {
        storage.removeValue(forKey: key)
    }
}

// MARK: - Network Client Protocol

public protocol NetworkClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension NetworkClient where Self == LiveNetworkClient {
    public static var live: Self { LiveNetworkClient() }
}

public struct LiveNetworkClient: NetworkClient {
    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await URLSession.shared.data(for: request)
    }
}

extension NetworkClient where Self == TestNetworkClient {
    public static func test(responses: [URLRequest: (Data, URLResponse)] = [:]) -> Self {
        TestNetworkClient(responses: responses)
    }
}

public final class TestNetworkClient: NetworkClient, @unchecked Sendable {
    public var responses: [URLRequest: (Data, URLResponse)]

    public init(responses: [URLRequest: (Data, URLResponse)] = [:]) {
        self.responses = responses
    }

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        guard let response = responses[request] else {
            throw URLError(.badServerResponse)
        }
        return response
    }
}

// MARK: - Keychain Service Protocol

public protocol KeychainServiceProtocol: Sendable {
    func set(_ value: String, forKey key: String) async throws
    func get(_ key: String) async throws -> String?
    func delete(_ key: String) async throws
}

extension KeychainServiceProtocol where Self == LiveKeychainService {
    public static var live: Self { LiveKeychainService() }
}

public struct LiveKeychainService: KeychainServiceProtocol {
    private let keychain = KeychainService.shared

    public func set(_ value: String, forKey key: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    try await keychain.set(value, forKey: key)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func get(_ key: String) async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let value = try await keychain.get(key)
                    continuation.resume(returning: value)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func delete(_ key: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    try await keychain.delete(key)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

extension KeychainServiceProtocol where Self == TestKeychainService {
    public static var test: Self { TestKeychainService() }
}

public final class TestKeychainService: KeychainServiceProtocol, @unchecked Sendable {
    public var storage: [String: String] = [:]

    public func set(_ value: String, forKey key: String) async throws {
        storage[key] = value
    }

    public func get(_ key: String) async throws -> String? {
        storage[key]
    }

    public func delete(_ key: String) async throws {
        storage.removeValue(forKey: key)
    }
}

// MARK: - Dependencies Integration

extension DependencyValues {
    public var clock: any Clock {
        get { self[ClockKey.self] }
        set { self[ClockKey.self] = newValue }
    }

    public var uuidGenerator: any UUIDGenerator {
        get { self[UUIDGeneratorKey.self] }
        set { self[UUIDGeneratorKey.self] = newValue }
    }

    public var logger: any Logger {
        get { self[LoggerKey.self] }
        set { self[LoggerKey.self] = newValue }
    }

    public var storage: any Storage {
        get { self[StorageKey.self] }
        set { self[StorageKey.self] = newValue }
    }

    public var networkClient: any NetworkClient {
        get { self[NetworkClientKey.self] }
        set { self[NetworkClientKey.self] = newValue }
    }

    public var keychainService: any KeychainServiceProtocol {
        get { self[KeychainServiceKey.self] }
        set { self[KeychainServiceKey.self] = newValue }
    }
}

private enum ClockKey: DependencyKey {
    static let liveValue: any Clock = LiveClock()
}

private enum UUIDGeneratorKey: DependencyKey {
    static let liveValue: any UUIDGenerator = LiveUUIDGenerator()
}

private enum LoggerKey: DependencyKey {
    static let liveValue: any Logger = LiveLogger()
}

private enum StorageKey: DependencyKey {
    static let liveValue: any Storage = LiveStorage()
}

private enum NetworkClientKey: DependencyKey {
    static let liveValue: any NetworkClient = LiveNetworkClient()
}

private enum KeychainServiceKey: DependencyKey {
    static let liveValue: any KeychainServiceProtocol = LiveKeychainService()
    static let testValue: any KeychainServiceProtocol = TestKeychainService()
}