import Core
import Foundation
import Generation
import SemanticMatcher

// MARK: - Interview Types

/// Mock interview session
public struct InterviewSession: Equatable, Codable, Sendable {
    public let id: UUID
    public let job: Job
    public let profile: Profile
    public let questions: [InterviewQuestion]
    public let responses: [InterviewResponse]
    public let feedback: InterviewFeedback?
    public let createdAt: Date
    public let completedAt: Date?

    public init(
        id: UUID = UUID(),
        job: Job,
        profile: Profile,
        questions: [InterviewQuestion] = [],
        responses: [InterviewResponse] = [],
        feedback: InterviewFeedback? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.job = job
        self.profile = profile
        self.questions = questions
        self.responses = responses
        self.feedback = feedback
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

/// Interview question with metadata
public struct InterviewQuestion: Equatable, Codable, Sendable {
    public let id: UUID
    public let question: String
    public let category: QuestionCategory
    public let difficulty: DifficultyLevel
    public let expectedDuration: TimeInterval // seconds

    public init(
        id: UUID = UUID(),
        question: String,
        category: QuestionCategory,
        difficulty: DifficultyLevel,
        expectedDuration: TimeInterval = 120
    ) {
        self.id = id
        self.question = question
        self.category = category
        self.difficulty = difficulty
        self.expectedDuration = expectedDuration
    }
}

/// User's response to interview question
public struct InterviewResponse: Equatable, Codable, Sendable {
    public let questionId: UUID
    public let response: String
    public let audioData: Data? // For voice responses
    public let responseTime: TimeInterval
    public let timestamp: Date

    public init(
        questionId: UUID,
        response: String,
        audioData: Data? = nil,
        responseTime: TimeInterval,
        timestamp: Date = Date()
    ) {
        self.questionId = questionId
        self.response = response
        self.audioData = audioData
        self.responseTime = responseTime
        self.timestamp = timestamp
    }
}

/// Comprehensive interview feedback
public struct InterviewFeedback: Equatable, Codable, Sendable {
    public let overallScore: Double // 0-100
    public let strengths: [String]
    public let improvements: [String]
    public let questionFeedback: [UUID: QuestionFeedback] // questionId -> feedback
    public let recommendations: [String]
    public let generatedAt: Date

    public init(
        overallScore: Double,
        strengths: [String],
        improvements: [String],
        questionFeedback: [UUID: QuestionFeedback],
        recommendations: [String],
        generatedAt: Date = Date()
    ) {
        self.overallScore = overallScore
        self.strengths = strengths
        self.improvements = improvements
        self.questionFeedback = questionFeedback
        self.recommendations = recommendations
        self.generatedAt = generatedAt
    }
}

/// Feedback for individual question
public struct QuestionFeedback: Equatable, Codable, Sendable {
    public let score: Double // 0-10
    public let strengths: [String]
    public let suggestions: [String]
    public let keyPoints: [String]

    public init(
        score: Double,
        strengths: [String],
        suggestions: [String],
        keyPoints: [String]
    ) {
        self.score = score
        self.strengths = strengths
        self.suggestions = suggestions
        self.keyPoints = keyPoints
    }
}

/// Question categories
public enum QuestionCategory: String, Codable, Sendable {
    case technical
    case behavioral
    case situational
    case companyCulture = "company_culture"
    case leadership
    case problemSolving = "problem_solving"
}

/// Difficulty levels
public enum DifficultyLevel: String, Codable, Sendable {
    case beginner
    case intermediate
    case advanced
    case expert
}

// MARK: - Interview Coach Protocol

public protocol InterviewCoach: Sendable {
    func generateQuestions(for job: Job, profile: Profile, count: Int) async throws -> [InterviewQuestion]
    func startSession(job: Job, profile: Profile) async throws -> InterviewSession
    func submitResponse(sessionId: UUID, response: InterviewResponse) async throws -> InterviewSession
    func completeSession(sessionId: UUID) async throws -> InterviewSession
    func analyzePerformance(session: InterviewSession) async throws -> InterviewFeedback
    func getPracticeMaterials(for job: Job, category: QuestionCategory) async throws -> [String]
}

// MARK: - Live Implementation

extension InterviewCoach where Self == LiveInterviewCoach {
    public static var live: Self { LiveInterviewCoach() }
}

public struct LiveInterviewCoach: InterviewCoach {
    private let llmAdapter: any LLMAdapter
    private let semanticMatcher: any SemanticMatcher

    public init(
        llmAdapter: any LLMAdapter = .live,
        semanticMatcher: any SemanticMatcher = .live
    ) {
        self.llmAdapter = llmAdapter
        self.semanticMatcher = semanticMatcher
    }

    public func generateQuestions(for job: Job, profile: Profile, count: Int = 5) async throws -> [InterviewQuestion] {
        let enrichedJob = try await semanticMatcher.enrichJob(job)

        let prompt = """
        Generate \(count) interview questions for this job position. Mix of technical, behavioral, and situational questions.
        Consider the candidate's experience level and tailor questions accordingly.

        Job: \(job.title) at \(job.company)
        Description: \(job.description)
        Required Skills: \(enrichedJob.requiredSkills.joined(separator: ", "))
        Preferred Skills: \(enrichedJob.preferredSkills.joined(separator: ", "))

        Candidate Experience: \(profile.experience.map { "\($0.title) at \($0.company): \($0.description)" }.joined(separator: "; "))
        Skills: \(profile.skills.joined(separator: ", "))

        Return a JSON array of questions with this structure:
        [
          {
            "question": "string",
            "category": "technical|behavioral|situational|company_culture|leadership|problem_solving",
            "difficulty": "beginner|intermediate|advanced|expert"
          }
        ]
        """

        let response = try await llmAdapter.generate(prompt: prompt)

        guard let jsonData = response.data(using: String.Encoding.utf8),
              let rawQuestions = try? JSONDecoder().decode([RawQuestion].self, from: jsonData) else {
            throw InterviewCoachError.questionGenerationFailed
        }

        return rawQuestions.enumerated().map { index, raw in
            InterviewQuestion(
                question: raw.question,
                category: QuestionCategory(rawValue: raw.category) ?? .technical,
                difficulty: DifficultyLevel(rawValue: raw.difficulty) ?? .intermediate
            )
        }
    }

    public func startSession(job: Job, profile: Profile) async throws -> InterviewSession {
        let questions = try await generateQuestions(for: job, profile: profile, count: 5)
        return InterviewSession(job: job, profile: profile, questions: questions)
    }

    public func submitResponse(sessionId: UUID, response: InterviewResponse) async throws -> InterviewSession {
        // In a real implementation, this would update stored session data
        // For now, return a mock updated session
        throw InterviewCoachError.notImplemented
    }

    public func completeSession(sessionId: UUID) async throws -> InterviewSession {
        // In a real implementation, this would mark session as complete and generate feedback
        throw InterviewCoachError.notImplemented
    }

    public func analyzePerformance(session: InterviewSession) async throws -> InterviewFeedback {
        guard session.responses.count > 0 else {
            throw InterviewCoachError.insufficientData
        }

        let prompt = """
        Analyze this interview performance and provide detailed feedback.

        Job: \(session.job.title) at \(session.job.company)
        Questions and Responses:
        \(session.responses.enumerated().map { "Q\($0.offset + 1): \($0.element.response)" }.joined(separator: "\n"))

        Return JSON with:
        {
          "overallScore": number (0-100),
          "strengths": ["strength1", "strength2"],
          "improvements": ["improvement1", "improvement2"],
          "recommendations": ["rec1", "rec2"]
        }
        """

        let response = try await llmAdapter.generate(prompt: prompt)

        guard let jsonData = response.data(using: String.Encoding.utf8),
              let analysis = try? JSONDecoder().decode(FeedbackAnalysis.self, from: jsonData) else {
            return InterviewFeedback(
                overallScore: 75.0,
                strengths: ["Good communication skills"],
                improvements: ["Practice more technical questions"],
                questionFeedback: [:],
                recommendations: ["Review core concepts", "Practice common interview questions"]
            )
        }

        return InterviewFeedback(
            overallScore: analysis.overallScore,
            strengths: analysis.strengths,
            improvements: analysis.improvements,
            questionFeedback: [:], // Would be populated in full implementation
            recommendations: analysis.recommendations
        )
    }

    public func getPracticeMaterials(for job: Job, category: QuestionCategory) async throws -> [String] {
        let prompt = """
        Generate 5 practice \(category.rawValue) questions for \(job.title) position at \(job.company).

        Job Description: \(job.description)

        Return as a JSON array of strings.
        """

        let response = try await llmAdapter.generate(prompt: prompt)

        guard let jsonData = response.data(using: String.Encoding.utf8),
              let materials = try? JSONDecoder().decode([String].self, from: jsonData) else {
            return [
                "Tell me about yourself",
                "What are your strengths?",
                "Describe a challenging project",
                "Where do you see yourself in 5 years?",
                "Do you have any questions for us?"
            ]
        }

        return materials
    }
}

// MARK: - Helper Types

private struct RawQuestion: Codable {
    let question: String
    let category: String
    let difficulty: String
}

private struct FeedbackAnalysis: Codable {
    let overallScore: Double
    let strengths: [String]
    let improvements: [String]
    let recommendations: [String]
}

// MARK: - Errors

public enum InterviewCoachError: Error, LocalizedError {
    case questionGenerationFailed
    case notImplemented
    case insufficientData
    case invalidSession

    public var errorDescription: String? {
        switch self {
        case .questionGenerationFailed:
            return "Failed to generate interview questions"
        case .notImplemented:
            return "Feature not yet implemented"
        case .insufficientData:
            return "Not enough data to analyze performance"
        case .invalidSession:
            return "Invalid interview session"
        }
    }
}