import AutomationEngine
import Core
import Generation
import ResumeParser
import Testing

@Test("Create automation workflow")
func testCreateWorkflow() async throws {
    let engine = LiveAutomationEngine(llmAdapter: TestLLMAdapter(), resumeParser: TestResumeParser())

    let workflow = try await engine.createWorkflow(
        name: "Test Workflow",
        triggers: [.jobMatch(minScore: 0.8)],
        actions: [.scheduleReminder(title: "Test", message: "Test", delayHours: 24)]
    )

    #expect(workflow.name == "Test Workflow")
    #expect(workflow.isActive)
    #expect(workflow.triggers.count == 1)
    #expect(workflow.actions.count == 1)
}

@Test("Execute workflow")
func testExecuteWorkflow() async throws {
    let engine = LiveAutomationEngine(llmAdapter: TestLLMAdapter(), resumeParser: TestResumeParser())

    let workflow = try await engine.createWorkflow(
        name: "Test Execute",
        triggers: [.jobMatch(minScore: 0.8)],
        actions: [.scheduleReminder(title: "Test Reminder", message: "Test message", delayHours: 1)]
    )

    let job = Job(title: "Test Job", company: "Test Co", description: "Test", postedDate: Date(), url: "test", source: .linkedin)
    let profile = Profile(name: "Test", email: "test@example.com", summary: "Test")

    let result = try await engine.executeWorkflow(workflow, for: job, profile: profile)

    #expect(result.success)
    #expect(result.actions.count == 1)
}

@Test("Get active workflows")
func testGetActiveWorkflows() async throws {
    let engine = LiveAutomationEngine(llmAdapter: TestLLMAdapter(), resumeParser: TestResumeParser())

    let workflow1 = try await engine.createWorkflow(name: "Active", triggers: [], actions: [])
    let workflow2 = try await engine.createWorkflow(name: "Inactive", triggers: [], actions: [])
    try await engine.deactivateWorkflow(id: workflow2.id)

    let active = try await engine.getActiveWorkflows()

    #expect(active.count == 1)
    #expect(active.first?.id == workflow1.id)
}

private struct TestLLMAdapter: LLMAdapter {
    func generate(prompt: String) async throws -> String {
        return "Test generated content"
    }
}

private struct TestResumeParser: ResumeParser {
    func parseResume(from data: Data, fileName: String) async throws -> ParsedResume {
        return ParsedResume(contactInfo: ContactInfo(name: "Test User"))
    }

    func analyzeATSCompatibility(_ resume: ParsedResume, jobDescription: String) async throws -> ATSAnalysis {
        return ATSAnalysis(score: 85.0)
    }

    func optimizeForJob(_ resume: ParsedResume, job: Job) async throws -> OptimizedResume {
        return OptimizedResume(
            original: resume,
            job: job,
            optimizedContent: "Optimized resume content"
        )
    }
}