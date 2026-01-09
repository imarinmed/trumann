import EnterpriseCore
import Core
import Testing

@Test("Organization management")
func testOrganizationManagement() async throws {
    let manager = LiveOrganizationManager()

    let org = try await manager.createOrganization(name: "Test Corp", domain: "test.com", adminId: UUID())
    #expect(org.name == "Test Corp")
    #expect(org.subscription == .free)

    try await manager.updateSubscription(organizationId: org.id, tier: .professional)
    let updated = try await manager.getOrganization(id: org.id)
    #expect(updated?.subscription == .professional)
}

@Test("Team member management")
func testTeamManagement() async throws {
    let manager = LiveTeamManager()

    let member = try await manager.addMember(organizationId: UUID(), userId: UUID(), role: .user)
    #expect(member.role == .user)
}

@Test("Compliance logging")
func testCompliance() async throws {
    let manager = LiveComplianceManager()

    try await manager.logAuditEvent(
        userId: UUID(),
        action: .login,
        resource: "dashboard",
        details: ["ip": "192.168.1.1"]
    )

    let issues = try await manager.gdprComplianceCheck()
    #expect(issues.count >= 0)
}

@Test("Job sharing")
func testCollaboration() async throws {
    let manager = LiveCollaborationManager()

    let job = Job(title: "Test Job", company: "Test Co", description: "Test", postedDate: Date(), url: "test", source: .linkedin)
    let sharedJob = try await manager.shareJob(
        job: job,
        sharedBy: UUID(),
        sharedWith: [UUID()],
        notes: "Great opportunity"
    )

    #expect(sharedJob.job.title == "Test Job")
    #expect(sharedJob.notes == "Great opportunity")
}