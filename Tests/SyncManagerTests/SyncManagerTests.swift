import SyncManager
import Core
import Testing

@Test("Sync manager basic operations")
func testSyncManager() async throws {
    let manager = LiveSyncManager()

    // Test enabling/disabling sync
    manager.enableSync()
    // Should be enabled by default

    manager.disableSync()
    // Test would verify sync is disabled
}

@Test("Syncable protocol conformance")
func testSyncableConformance() {
    let profile = Profile(name: "Test", email: "test@example.com", summary: "Test")
    let application = Application(jobId: UUID(), appliedDate: Date())
    let job = Job(title: "Test Job", company: "Test Co", description: "Test", postedDate: Date(), url: "test", source: .linkedin)

    // Test that they conform to Syncable
    #expect(profile.syncId == profile.id.uuidString)
    #expect(application.syncId == application.id.uuidString)
    #expect(job.syncId == job.id.uuidString)
}

@Test("OAuth token structure")
func testOAuthToken() {
    let token = OAuthToken(
        accessToken: "test_token",
        refreshToken: "refresh_token",
        expiresAt: Date().addingTimeInterval(3600),
        provider: .linkedin
    )

    #expect(token.accessToken == "test_token")
    #expect(token.provider == .linkedin)
}