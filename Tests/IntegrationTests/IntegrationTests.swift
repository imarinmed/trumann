import Core
import Ingestion
import Ranking
import Generation
import Tracking
import Adapters
import Foundation
import Dependencies
import Testing

private struct TestLLMAdapter: LLMAdapter {
    func generate(prompt: String) async throws -> String {
        if prompt.contains("CV") {
            return """
            John Doe
            john@example.com

            Senior Software Engineer
            Tech Corp

            Experienced software engineer with background in building scalable systems.
            """
        } else {
            return """
            Dear Hiring Manager,

            I am writing to apply for the Senior Software Engineer position at Tech Corp.
            My experience at Previous Corp building scalable systems makes me a great fit.

            Thank you for considering my application.

            Best regards,
            John Doe
            """
        }
    }
}

@Test("End-to-end job search and application flow")
func testJobSearchToApplicationFlow() async throws {
    // Test the complete flow: search -> rank -> generate -> track

    let query = JobQuery(
        keywords: "software engineer",
        location: "San Francisco",
        remote: true,
        salaryMin: 100000
    )

    let mockAdapter = TestJobAdapter(jobs: [
        Job(
            title: "Senior Software Engineer",
            company: "Tech Corp",
            description: "Build amazing software...",
            location: "San Francisco, CA",
            salary: Salary(min: 120000, max: 150000, currency: "USD", period: .yearly),
            postedDate: Date(),
            url: "https://example.com/job1",
            source: .indeed
        ),
        Job(
            title: "Software Developer",
            company: "Startup Inc",
            description: "Learn and grow...",
            location: "San Francisco, CA",
            salary: Salary(min: 110000, max: 130000, currency: "USD", period: .yearly),
            postedDate: Date(),
            url: "https://example.com/job2",
            source: .linkedin
        )
    ])

    // Search jobs
    let foundJobs = try await mockAdapter.searchJobs(query: query)

    #expect(foundJobs.count == 2)

    // Rank jobs
    let ranker = JobRanker()
    let rankedJobs = ranker.rank(jobs: foundJobs, query: query)

    #expect(rankedJobs.count == 2)
    #expect(rankedJobs[0].score > rankedJobs[1].score) // Senior role should rank higher

    try await withDependencies {
        $0.networkClient = TestNetworkClient()
    } operation: {
        let profile = Profile(
            name: "John Doe",
            email: "john@example.com",
            summary: "Experienced software engineer",
            experience: [
                Experience(
                    title: "Software Engineer",
                    company: "Previous Corp",
                    startDate: Date().addingTimeInterval(-365*24*3600),
                    description: "Built scalable systems"
                )
            ],
            skills: ["Swift", "iOS", "Python"]
        )

        let templateEngine = TemplateEngine(adapter: TestLLMAdapter())
        let cv = try await templateEngine.generateCV(profile: profile, job: rankedJobs[0].job)
        #expect(cv.contains("John Doe"))
        #expect(cv.contains("Senior Software Engineer"))

        // Generate cover letter
        let coverLetter = try await templateEngine.generateCoverLetter(profile: profile, job: rankedJobs[0].job)
        #expect(coverLetter.contains("Dear Hiring Manager"))
        #expect(coverLetter.contains("Tech Corp"))

        // Track application
        let application = Application(jobId: rankedJobs[0].job.id, status: ApplicationStatus.applied)
        // Note: Tracking module would store this, but for test we just verify creation
        #expect(application.jobId == rankedJobs[0].job.id)
        #expect(application.status == ApplicationStatus.applied)
    }
}

private struct TestJobAdapter: JobSourceAdapter {
    let source: JobSource = .custom
    let jobs: [Job]

    func searchJobs(query: JobQuery) async throws -> [Job] {
        // Simple filtering for test - return all jobs
        jobs
    }
}