import Testing
import Foundation
@testable import Core

@Test func jobCreation() {
    let job = Job(
        title: "Software Engineer",
        company: "Apple",
        description: "Build great apps",
        location: "Cupertino, CA",
        salary: Salary(min: 100000, max: 150000, currency: "USD", period: .yearly),
        postedDate: Date(),
        url: "https://apple.com/job",
        source: .linkedin
    )

    #expect(job.title == "Software Engineer")
    #expect(job.company == "Apple")
    #expect(job.salary?.min == 100000)
    #expect(job.source == .linkedin)
}

@Test func consentStateFromATTStatus() {
    #expect(ConsentState(from: .authorized) == .authorized)
    #expect(ConsentState(from: .denied) == .denied)
    #expect(ConsentState(from: .notDetermined) == .notDetermined)
    #expect(ConsentState(from: .restricted) == .restricted)
}

@Test func testClock() {
    let testClock = TestClock()
    let now = testClock.now
    #expect(now.timeIntervalSinceReferenceDate > 0)
}

@Test func testUUIDGenerator() {
    let generator = TestUUIDGenerator(uuids: [UUID(), UUID()])
    #expect(generator.uuid() != generator.uuid())
}

@Test func testLogger() {
    let logger = TestLogger()
    logger.log(level: .info, message: "Test message", metadata: ["key": "value"])
    #expect(logger.logs.count == 1)
    #expect(logger.logs[0].message == "Test message")
    #expect(logger.logs[0].metadata["key"] == "value")
}

// Storage test skipped - Job not Codable yet

@Test func domainErrorEquatable() {
    #expect(DomainError.invalidJobData("test") == .invalidJobData("test"))
    #expect(DomainError.networkError("error") == .networkError("error"))
    #expect(DomainError.consentRequired != .networkError(""))
}

@Test func keychainService() async throws {
    let keychain = KeychainService.shared
    let key = "test_key"
    let value = "test_value"

    try await keychain.set(value, forKey: key)
    let retrieved = try await keychain.get(key)
    #expect(retrieved == value)

    let exists = try await keychain.exists(key)
    #expect(exists)

    try await keychain.delete(key)
    let afterDelete = try await keychain.get(key)
    #expect(afterDelete == nil)
}

@Test func storageEncryption() async throws {
    let storage = LiveStorage()
    let job = Job(title: "Test", company: "TestCo", description: "Desc", postedDate: Date(), url: "https://test.com", source: .linkedin)

    try await storage.save(job, forKey: "test-job")
    let loaded: Job? = try await storage.load(Job.self, forKey: "test-job")
    #expect(loaded?.title == "Test")
}
