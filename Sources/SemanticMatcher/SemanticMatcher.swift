import Core
import Foundation
import Generation

// MARK: - Semantic Matching Types

/// Result of semantic job matching
public struct SemanticMatchResult: Equatable, Sendable {
    public let job: Job
    public let score: Double  // 0-1 semantic similarity
    public let keywordMatches: [String]
    public let semanticExplanation: String
    public let companyInsights: CompanyInsights?

    public init(
        job: Job,
        score: Double,
        keywordMatches: [String] = [],
        semanticExplanation: String,
        companyInsights: CompanyInsights? = nil
    ) {
        self.job = job
        self.score = score
        self.keywordMatches = keywordMatches
        self.semanticExplanation = semanticExplanation
        self.companyInsights = companyInsights
    }
}

/// Company insights from semantic analysis
public struct CompanyInsights: Equatable, Codable, Sendable {
    public let companyName: String
    public let industry: String?
    public let size: String?
    public let culture: String?
    public let benefits: [String]?
    public let growth: String?

    public init(
        companyName: String,
        industry: String? = nil,
        size: String? = nil,
        culture: String? = nil,
        benefits: [String]? = nil,
        growth: String? = nil
    ) {
        self.companyName = companyName
        self.industry = industry
        self.size = size
        self.culture = culture
        self.benefits = benefits
        self.growth = growth
    }
}

/// Enhanced job with semantic data
public struct SemanticJob: Equatable, Sendable {
    public let job: Job
    public let semanticKeywords: [String]
    public let requiredSkills: [String]
    public let preferredSkills: [String]
    public let companyInsights: CompanyInsights?
    public let roleLevel: String?
    public let salaryInsights: String?

    public init(
        job: Job,
        semanticKeywords: [String] = [],
        requiredSkills: [String] = [],
        preferredSkills: [String] = [],
        companyInsights: CompanyInsights? = nil,
        roleLevel: String? = nil,
        salaryInsights: String? = nil
    ) {
        self.job = job
        self.semanticKeywords = semanticKeywords
        self.requiredSkills = requiredSkills
        self.preferredSkills = preferredSkills
        self.companyInsights = companyInsights
        self.roleLevel = roleLevel
        self.salaryInsights = salaryInsights
    }
}

// MARK: - Semantic Matcher Protocol

public protocol SemanticMatcher: Sendable {
    func enrichJob(_ job: Job) async throws -> SemanticJob
    func matchJobs(_ jobs: [Job], profile: Profile) async throws -> [SemanticMatchResult]
    func analyzeCompany(_ job: Job) async throws -> CompanyInsights?
}

// MARK: - Live Implementation

extension SemanticMatcher where Self == LiveSemanticMatcher {
    public static var live: Self { LiveSemanticMatcher() }
}

public struct LiveSemanticMatcher: SemanticMatcher {
    private let llmAdapter: any LLMAdapter

    public init(llmAdapter: any LLMAdapter = .live) {
        self.llmAdapter = llmAdapter
    }

    public func enrichJob(_ job: Job) async throws -> SemanticJob {
        let prompt = """
        Analyze this job posting and extract structured semantic information.
        Return a JSON object with this exact structure:
        {
          "semanticKeywords": ["keyword1", "keyword2"],
          "requiredSkills": ["skill1", "skill2"],
          "preferredSkills": ["skill1", "skill2"],
          "roleLevel": "entry/mid/senior/executive",
          "salaryInsights": "salary range description or null"
        }

        Job Title: \(job.title)
        Company: \(job.company)
        Description: \(job.description)
        """

        let response = try await llmAdapter.generate(prompt: prompt)

        guard let jsonData = response.data(using: String.Encoding.utf8),
              let enrichment = try? JSONDecoder().decode(JobEnrichment.self, from: jsonData) else {
            // Fallback to basic enrichment
            return SemanticJob(
                job: job,
                semanticKeywords: extractBasicKeywords(job),
                requiredSkills: [],
                preferredSkills: []
            )
        }

        return SemanticJob(
            job: job,
            semanticKeywords: enrichment.semanticKeywords,
            requiredSkills: enrichment.requiredSkills,
            preferredSkills: enrichment.preferredSkills,
            roleLevel: enrichment.roleLevel,
            salaryInsights: enrichment.salaryInsights
        )
    }

    public func matchJobs(_ jobs: [Job], profile: Profile) async throws -> [SemanticMatchResult] {
        var results: [SemanticMatchResult] = []

        for job in jobs {
            let enrichedJob = try await enrichJob(job)

            let prompt = """
            Compare this job with the candidate's profile and calculate semantic similarity.
            Return a JSON object with this exact structure:
            {
              "score": 0.85,
              "keywordMatches": ["swift", "ios"],
              "semanticExplanation": "brief explanation of match quality"
            }

            Candidate Profile:
            Summary: \(profile.summary)
            Experience: \(profile.experience.map { "\($0.title) at \($0.company): \($0.description)" }.joined(separator: "; "))
            Skills: \(profile.skills.joined(separator: ", "))

            Job:
            Title: \(job.title)
            Description: \(job.description)
            Required Skills: \(enrichedJob.requiredSkills.joined(separator: ", "))
            Preferred Skills: \(enrichedJob.preferredSkills.joined(separator: ", "))
            """

            let response = try await llmAdapter.generate(prompt: prompt)

            if let jsonData = response.data(using: String.Encoding.utf8),
               let match = try? JSONDecoder().decode(JobMatch.self, from: jsonData) {
                let companyInsights = try await analyzeCompany(job)
                let result = SemanticMatchResult(
                    job: job,
                    score: match.score,
                    keywordMatches: match.keywordMatches,
                    semanticExplanation: match.semanticExplanation,
                    companyInsights: companyInsights
                )
                results.append(result)
            } else {
                // Fallback
                let result = SemanticMatchResult(
                    job: job,
                    score: 0.5,
                    semanticExplanation: "Unable to analyze match quality"
                )
                results.append(result)
            }
        }

        // Sort by score descending
        return results.sorted { $0.score > $1.score }
    }

    public func analyzeCompany(_ job: Job) async throws -> CompanyInsights? {
        let prompt = """
        Research and analyze this company based on the job posting.
        Return a JSON object with this exact structure:
        {
          "industry": "tech/software/finance/etc",
          "size": "startup/small/medium/large/enterprise",
          "culture": "brief culture description",
          "benefits": ["benefit1", "benefit2"],
          "growth": "growth stage description"
        }

        Company: \(job.company)
        Job Context: \(job.description)
        """

        let response = try await llmAdapter.generate(prompt: prompt)

        guard let jsonData = response.data(using: String.Encoding.utf8),
              let insights = try? JSONDecoder().decode(CompanyInsights.self, from: jsonData) else {
            return nil
        }

        return CompanyInsights(
            companyName: job.company,
            industry: insights.industry,
            size: insights.size,
            culture: insights.culture,
            benefits: insights.benefits,
            growth: insights.growth
        )
    }

    private func extractBasicKeywords(_ job: Job) -> [String] {
        let text = "\(job.title) \(job.description)"
        // Simple keyword extraction
        let commonTech = ["swift", "ios", "python", "javascript", "react", "aws", "docker", "kubernetes"]
        return commonTech.filter { text.lowercased().contains($0) }
    }
}

// MARK: - Helper Types

private struct JobEnrichment: Codable {
    let semanticKeywords: [String]
    let requiredSkills: [String]
    let preferredSkills: [String]
    let roleLevel: String?
    let salaryInsights: String?
}

private struct JobMatch: Codable {
    let score: Double
    let keywordMatches: [String]
    let semanticExplanation: String
}