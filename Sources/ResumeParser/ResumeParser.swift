import Core
import Foundation
import Dependencies
import Generation

// MARK: - Parsed Resume Types

/// Structured representation of a parsed resume
public struct ParsedResume: Equatable, Codable, Sendable {
    public let contactInfo: ContactInfo
    public let summary: String?
    public let experience: [Experience]
    public let education: [Education]
    public let skills: [String]
    public let certifications: [String]
    public let languages: [String]

    public init(
        contactInfo: ContactInfo,
        summary: String? = nil,
        experience: [Experience] = [],
        education: [Education] = [],
        skills: [String] = [],
        certifications: [String] = [],
        languages: [String] = []
    ) {
        self.contactInfo = contactInfo
        self.summary = summary
        self.experience = experience
        self.education = education
        self.skills = skills
        self.certifications = certifications
        self.languages = languages
    }
}

public struct ContactInfo: Equatable, Codable, Sendable {
    public let name: String
    public let email: String?
    public let phone: String?
    public let location: String?
    public let linkedin: String?
    public let github: String?

    public init(
        name: String,
        email: String? = nil,
        phone: String? = nil,
        location: String? = nil,
        linkedin: String? = nil,
        github: String? = nil
    ) {
        self.name = name
        self.email = email
        self.phone = phone
        self.location = location
        self.linkedin = linkedin
        self.github = github
    }
}

// MARK: - ATS Optimization Types

/// ATS compatibility analysis result
public struct ATSAnalysis: Equatable, Codable, Sendable {
    public let score: Double  // 0-100
    public let keywords: [String: Double]  // keyword -> relevance score
    public let formattingIssues: [String]
    public let recommendations: [String]

    public init(
        score: Double,
        keywords: [String: Double] = [:],
        formattingIssues: [String] = [],
        recommendations: [String] = []
    ) {
        self.score = score
        self.keywords = keywords
        self.formattingIssues = formattingIssues
        self.recommendations = recommendations
    }
}

/// Optimized resume for specific job
public struct OptimizedResume: Equatable, Sendable {
    public let original: ParsedResume
    public let job: Job
    public let optimizedContent: String
    public let keywordMatches: [String]
    public let atsScore: Double

    public init(
        original: ParsedResume,
        job: Job,
        optimizedContent: String,
        keywordMatches: [String] = [],
        atsScore: Double = 0.0
    ) {
        self.original = original
        self.job = job
        self.optimizedContent = optimizedContent
        self.keywordMatches = keywordMatches
        self.atsScore = atsScore
    }
}

// MARK: - Resume Parser Protocol

public protocol ResumeParser: Sendable {
    func parseResume(from data: Data, fileName: String) async throws -> ParsedResume
    func analyzeATSCompatibility(_ resume: ParsedResume, jobDescription: String) async throws -> ATSAnalysis
    func optimizeForJob(_ resume: ParsedResume, job: Job) async throws -> OptimizedResume
}

// MARK: - Live Implementation

extension ResumeParser where Self == LiveResumeParser {
    public static var live: Self { LiveResumeParser() }
}

public struct LiveResumeParser: ResumeParser {
    private let llmAdapter: any LLMAdapter

    public init(llmAdapter: any LLMAdapter = .live) {
        self.llmAdapter = llmAdapter
    }

    public func parseResume(from data: Data, fileName: String) async throws -> ParsedResume {
        // For now, use LLM to parse text content
        // In production, integrate PDF parsing library
        guard let text = String(data: data, encoding: .utf8) else {
            throw ResumeParserError.invalidFormat
        }

        let prompt = """
        Parse the following resume text and extract structured information.
        Return a JSON object with this exact structure:
        {
          "contactInfo": {
            "name": "string",
            "email": "string or null",
            "phone": "string or null",
            "location": "string or null",
            "linkedin": "string or null",
            "github": "string or null"
          },
          "summary": "string or null",
          "experience": [
            {
              "title": "string",
              "company": "string",
              "startDate": "YYYY-MM-DD",
              "endDate": "YYYY-MM-DD or null",
              "description": "string"
            }
          ],
          "education": [
            {
              "degree": "string",
              "institution": "string",
              "graduationDate": "YYYY-MM-DD or null"
            }
          ],
          "skills": ["string"],
          "certifications": ["string"],
          "languages": ["string"]
        }

        Resume text:
        \(text)
        """

        let response = try await llmAdapter.generate(prompt: prompt)

        // Parse JSON response
        guard let jsonData = response.data(using: String.Encoding.utf8),
              let parsed = try? JSONDecoder().decode(ParsedResume.self, from: jsonData) else {
            throw ResumeParserError.parsingFailed
        }

        return parsed
    }

    public func analyzeATSCompatibility(_ resume: ParsedResume, jobDescription: String) async throws -> ATSAnalysis {
        let prompt = """
        Analyze this resume for ATS compatibility against the job description.
        Provide a JSON response with:
        {
          "score": number (0-100),
          "keywords": {"keyword": relevance_score},
          "formattingIssues": ["issue1", "issue2"],
          "recommendations": ["rec1", "rec2"]
        }

        Resume: \(resumeToText(resume))
        Job Description: \(jobDescription)
        """

        let response = try await llmAdapter.generate(prompt: prompt)

        guard let jsonData = response.data(using: String.Encoding.utf8),
              let analysis = try? JSONDecoder().decode(ATSAnalysis.self, from: jsonData) else {
            return ATSAnalysis(score: 75.0, recommendations: ["Unable to analyze - please check manually"])
        }

        return analysis
    }

    public func optimizeForJob(_ resume: ParsedResume, job: Job) async throws -> OptimizedResume {
        let prompt = """
        Optimize this resume for the specific job. Focus on:
        1. Incorporating relevant keywords from job description
        2. Tailoring experience descriptions
        3. Highlighting relevant skills
        4. ATS-friendly formatting

        Return the optimized resume as plain text.

        Original Resume: \(resumeToText(resume))
        Job Title: \(job.title)
        Job Description: \(job.description)
        """

        let optimizedContent = try await llmAdapter.generate(prompt: prompt)

        // Extract keywords (simplified)
        let keywords = extractKeywords(from: job.description)

        return OptimizedResume(
            original: resume,
            job: job,
            optimizedContent: optimizedContent,
            keywordMatches: keywords,
            atsScore: 85.0  // Placeholder
        )
    }

    private func resumeToText(_ resume: ParsedResume) -> String {
        var text = """
        Name: \(resume.contactInfo.name)
        Email: \(resume.contactInfo.email ?? "N/A")
        Phone: \(resume.contactInfo.phone ?? "N/A")
        Location: \(resume.contactInfo.location ?? "N/A")

        Summary: \(resume.summary ?? "N/A")

        Experience:
        """

        for exp in resume.experience {
            text += "\n- \(exp.title) at \(exp.company): \(exp.description)"
        }

        text += "\n\nEducation:\n"
        for edu in resume.education {
            text += "- \(edu.degree) from \(edu.institution)\n"
        }

        text += "\nSkills: \(resume.skills.joined(separator: ", "))"
        text += "\nCertifications: \(resume.certifications.joined(separator: ", "))"
        text += "\nLanguages: \(resume.languages.joined(separator: ", "))"

        return text
    }

    private func extractKeywords(from text: String) -> [String] {
        // Simple keyword extraction - in production, use NLP
        let common = ["swift", "ios", "python", "javascript", "react", "node", "aws", "docker"]
        return common.filter { text.lowercased().contains($0) }
    }
}

// MARK: - Dependencies Integration

extension DependencyValues {
    public var resumeParser: any ResumeParser {
        get { self[ResumeParserKey.self] }
        set { self[ResumeParserKey.self] = newValue }
    }
}

private enum ResumeParserKey: DependencyKey {
    static let liveValue: any ResumeParser = LiveResumeParser()
}

// MARK: - Errors

public enum ResumeParserError: Error, LocalizedError {
    case invalidFormat
    case parsingFailed
    case unsupportedFileType

    public var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Resume file format is not supported"
        case .parsingFailed:
            return "Failed to parse resume content"
        case .unsupportedFileType:
            return "File type not supported for resume parsing"
        }
    }
}