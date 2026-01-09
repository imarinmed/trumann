import Core
import Dependencies
import Foundation

// MARK: - LLM Adapter Protocol

public protocol LLMAdapter: Sendable {
    func generate(prompt: String) async throws -> String
}

extension LLMAdapter where Self == LiveLLMAdapter {
    public static var live: Self { LiveLLMAdapter() }
}

// OpenAI API Models
private struct OpenAIRequest: Encodable {
    let model: String
    let messages: [Message]
    let max_tokens: Int
    let temperature: Double

    struct Message: Encodable {
        let role: String
        let content: String
    }
}

private struct OpenAIResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String
    }
}

public struct LiveLLMAdapter: LLMAdapter {
    @Dependency(\.keychainService) var keychain
    @Dependency(\.networkClient) var networkClient
    private let apiKeyKey = "openai_api_key"

    public init() {}

    public func generate(prompt: String) async throws -> String {
        // Try to get API key from keychain
        guard let apiKey = try await keychain.get(apiKeyKey), !apiKey.isEmpty else {
            // Fallback to stub if no key
            return """
            Dear Hiring Manager,

            I am excited to apply for the position. With my background in software development,
            I am confident I can contribute to your team.

            Best regards,
            Applicant
            """
        }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let openAIRequest = OpenAIRequest(
            model: "gpt-3.5-turbo",
            messages: [.init(role: "user", content: prompt)],
            max_tokens: 1000,
            temperature: 0.7
        )

        request.httpBody = try JSONEncoder().encode(openAIRequest)

        let (data, response) = try await networkClient.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        return openAIResponse.choices.first?.message.content ?? "Error: No response"
    }

    public func setAPIKey(_ key: String) async throws {
        try await keychain.set(key, forKey: apiKeyKey)
    }
}

extension LLMAdapter where Self == OfflineLLMAdapter {
    public static var offline: Self { OfflineLLMAdapter() }
}

public struct OfflineLLMAdapter: LLMAdapter {
    public func generate(prompt: String) async throws -> String {
        // Offline fallback: basic template
        """
        Dear Hiring Manager,

        I am writing to express my interest in the position. My skills and experience
        make me a strong candidate for this role.

        Thank you for considering my application.

        Sincerely,
        [Your Name]
        """
    }
}

// MARK: - Template Engine

public struct TemplateEngine: Sendable {
    private let adapter: any LLMAdapter

    public init(adapter: any LLMAdapter = .live) {
        self.adapter = adapter
    }

    public func generateCoverLetter(profile: Profile, job: Job) async throws -> String {
        let prompt = buildCoverLetterPrompt(profile: profile, job: job)
        var content = try await adapter.generate(prompt: prompt)
        content = applyATSConstraints(content)
        content = redactSensitiveInfo(content, profile: profile)
        return content
    }

    public func generateCV(profile: Profile, job: Job? = nil) async throws -> String {
        let prompt = buildCVPrompt(profile: profile, job: job)
        var content = try await adapter.generate(prompt: prompt)
        content = applyATSConstraints(content)
        content = redactSensitiveInfo(content, profile: profile)
        return content
    }

    private func buildCoverLetterPrompt(profile: Profile, job: Job) -> String {
        return """
        Write a professional cover letter for the following job application:

        Job Title: \(job.title)
        Company: \(job.company)
        Job Description: \(job.description)

        Applicant Profile:
        Name: \(profile.name)
        Summary: \(profile.summary)
        Experience: \(profile.experience.map { "\($0.title) at \($0.company): \($0.description)" }.joined(separator: "; "))
        Skills: \(profile.skills.joined(separator: ", "))

        Make it ATS-friendly: use standard fonts, avoid graphics, include keywords from job description.
        Keep it to 3-4 paragraphs, professional tone.
        """
    }

    private func buildCVPrompt(profile: Profile, job: Job?) -> String {
        let jobContext = job.map { "tailored for \($0.title) at \($0.company)" } ?? ""
        return """
        Generate a professional CV/resume \(jobContext):

        Personal Info:
        Name: \(profile.name)
        Summary: \(profile.summary)

        Experience:
        \(profile.experience.map { "- \($0.title) at \($0.company) (\(formatDate($0.startDate)) - \(formatDate($0.endDate)))\n  \($0.description)" }.joined(separator: "\n"))

        Education:
        \(profile.education.map { "- \($0.degree) from \($0.institution)\(formatDate($0.graduationDate))" }.joined(separator: "\n"))

        Skills: \(profile.skills.joined(separator: ", "))

        Format as clean text, ATS-compatible, 1-2 pages worth of content.
        """
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "Present" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }

    private func applyATSConstraints(_ content: String) -> String {
        // Remove special characters that might confuse ATS
        content
            .replacingOccurrences(of: "•", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
    }

    private func redactSensitiveInfo(_ content: String, profile: Profile) -> String {
        // Additional redaction beyond LLM
        content
            .replacingOccurrences(of: profile.email, with: "[EMAIL]", options: .caseInsensitive)
            .replacingOccurrences(of: profile.phone ?? "", with: "[PHONE]")
    }
}

// MARK: - Content Validators

public struct ContentValidator: Sendable {
    public static func validateLength(_ content: String, maxLength: Int = 5000) -> Bool {
        content.count <= maxLength
    }

    public static func validateATSCompliance(_ content: String) -> Bool {
        // Basic checks: no images, standard formatting
        !content.contains("image:") &&
        !content.contains("font-family") &&
        content.count > 10  // Reasonable minimum
    }

    public static func checkForBannedTerms(_ content: String, banned: [String] = ["confidential", "secret"]) -> Bool {
        !banned.contains { content.lowercased().contains($0) }
    }
}
