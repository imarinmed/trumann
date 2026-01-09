import InterviewCoach
import Core
import Generation
import Foundation
import Testing

@Test("Generate interview questions for job")
func testQuestionGeneration() async throws {
    let coach = LiveInterviewCoach(llmAdapter: TestLLMAdapter())

    let job = Job(
        title: "Senior iOS Developer",
        company: "Tech Corp",
        description: "Build iOS apps with Swift",
        postedDate: Date(),
        url: "https://example.com/job",
        source: .linkedin
    )

    let profile = Profile(
        name: "John Doe",
        email: "john@example.com",
        summary: "iOS developer",
        skills: ["Swift", "iOS"]
    )

    let questions = try await coach.generateQuestions(for: job, profile: profile, count: 3)

    #expect(questions.count == 3)
    #expect(questions.allSatisfy { !$0.question.isEmpty })
}

@Test("Analyze interview performance")
func testPerformanceAnalysis() async throws {
    let coach = LiveInterviewCoach(llmAdapter: TestLLMAdapter())

    let session = InterviewSession(
        job: Job(title: "Developer", company: "Company", description: "Job desc", postedDate: Date(), url: "url", source: .linkedin),
        profile: Profile(name: "John", email: "john@example.com", summary: "Developer"),
        questions: [
            InterviewQuestion(question: "Tell me about yourself", category: .behavioral, difficulty: .beginner)
        ],
        responses: [
            InterviewResponse(questionId: UUID(), response: "I am a developer with 5 years experience", responseTime: 60)
        ]
    )

    let feedback = try await coach.analyzePerformance(session: session)

    #expect(feedback.overallScore >= 0 && feedback.overallScore <= 100)
    #expect(feedback.strengths.count > 0)
}

@Test("Get practice materials")
func testPracticeMaterials() async throws {
    let coach = LiveInterviewCoach(llmAdapter: TestLLMAdapter())

    let job = Job(title: "Developer", company: "Company", description: "Job", postedDate: Date(), url: "url", source: .linkedin)

    let materials = try await coach.getPracticeMaterials(for: job, category: .technical)

    #expect(materials.count > 0)
    #expect(materials.allSatisfy { !$0.isEmpty })
}

private struct TestLLMAdapter: LLMAdapter {
    func generate(prompt: String) async throws -> String {
        if prompt.contains("questions") {
            return """
            [
              {"question": "Tell me about your experience with Swift", "category": "technical", "difficulty": "intermediate"},
              {"question": "Describe a challenging project", "category": "behavioral", "difficulty": "advanced"},
              {"question": "How do you handle tight deadlines?", "category": "situational", "difficulty": "intermediate"}
            ]
            """
        } else if prompt.contains("Analyze this interview") {
            return """
            {
              "overallScore": 85.0,
              "strengths": ["Good communication", "Relevant experience"],
              "improvements": ["More specific examples", "Quantify achievements"],
              "recommendations": ["Practice STAR method", "Prepare questions for interviewer"]
            }
            """
        } else if prompt.contains("practice") {
            return """
            ["What is your experience with version control?", "How do you debug complex issues?", "Tell me about your testing approach", "How do you stay updated with technology?", "Describe your code review process"]
            """
        } else {
            return "Test response"
        }
    }
}