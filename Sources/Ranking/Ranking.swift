import Core
import Foundation

// MARK: - Ranking Weights

public struct RankingWeights: Equatable, Sendable {
    public let titleWeight: Double
    public let descriptionWeight: Double
    public let companyWeight: Double
    public let recencyWeight: Double
    public let sourceWeight: Double

    public static let `default` = RankingWeights(
        titleWeight: 0.4,
        descriptionWeight: 0.3,
        companyWeight: 0.1,
        recencyWeight: 0.1,
        sourceWeight: 0.1
    )

    public init(
        titleWeight: Double = 0.4,
        descriptionWeight: Double = 0.3,
        companyWeight: Double = 0.1,
        recencyWeight: Double = 0.1,
        sourceWeight: Double = 0.1
    ) {
        self.titleWeight = titleWeight
        self.descriptionWeight = descriptionWeight
        self.companyWeight = companyWeight
        self.recencyWeight = recencyWeight
        self.sourceWeight = sourceWeight
    }
}

// MARK: - TF-IDF Scorer

public final class TFIDFScorer: @unchecked Sendable {
    private let corpus: [String]
    private var idfCache: [String: Double] = [:]

    public init(corpus: [String]) {
        self.corpus = corpus
        precomputeIDF()
    }

    public func score(query: String, document: String) -> Double {
        let queryTerms = tokenize(query)
        let docTerms = tokenize(document)

        var score = 0.0
        for term in queryTerms {
            let tf = termFrequency(term, in: docTerms)
            let idf = idfCache[term] ?? 0.0
            score += tf * idf
        }
        return score
    }

    private func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    private func termFrequency(_ term: String, in terms: [String]) -> Double {
        let count = terms.filter { $0 == term }.count
        return Double(count) / Double(terms.count)
    }

    private func precomputeIDF() {
        let allTerms = Set(corpus.flatMap(tokenize))
        for term in allTerms {
            let docsContainingTerm = corpus.filter { tokenize($0).contains(term) }.count
            let idf = log(Double(corpus.count) / Double(docsContainingTerm + 1))
            idfCache[term] = idf
        }
    }
}

// MARK: - Cosine Similarity

public func cosineSimilarity(_ vectorA: [Double], _ vectorB: [Double]) -> Double {
    let dotProduct = zip(vectorA, vectorB).map(*).reduce(0, +)
    let magnitudeA = sqrt(vectorA.map { $0 * $0 }.reduce(0, +))
    let magnitudeB = sqrt(vectorB.map { $0 * $0 }.reduce(0, +))

    guard magnitudeA > 0, magnitudeB > 0 else { return 0.0 }
    return dotProduct / (magnitudeA * magnitudeB)
}

// MARK: - Job Ranker

public struct JobRanker: Sendable {
    private let weights: RankingWeights
    private let scorer: TFIDFScorer

    public init(weights: RankingWeights = .default, corpus: [String] = []) {
        self.weights = weights
        self.scorer = TFIDFScorer(corpus: corpus)
    }

    public func rank(jobs: [Job], query: JobQuery) -> [RankedJob] {
        jobs.map { rank($0, query: query) }
            .sorted { $0.score > $1.score }
    }

    public func rank(_ job: Job, query: JobQuery) -> RankedJob {
        let titleScore = scorer.score(query: query.keywords, document: job.title) * weights.titleWeight
        let descScore = scorer.score(query: query.keywords, document: job.description) * weights.descriptionWeight
        let companyScore = scorer.score(query: query.keywords, document: job.company) * weights.companyWeight

        let recencyScore = calculateRecencyScore(job.postedDate) * weights.recencyWeight
        let sourceScore = calculateSourceScore(job.source) * weights.sourceWeight

        let totalScore = titleScore + descScore + companyScore + recencyScore + sourceScore

        let explanation = """
        Title: \(titleScore.formatted(.number.precision(.fractionLength(2))))
        Description: \(descScore.formatted(.number.precision(.fractionLength(2))))
        Company: \(companyScore.formatted(.number.precision(.fractionLength(2))))
        Recency: \(recencyScore.formatted(.number.precision(.fractionLength(2))))
        Source: \(sourceScore.formatted(.number.precision(.fractionLength(2))))
        """

        return RankedJob(job: job, score: totalScore, explanation: explanation)
    }

    private func calculateRecencyScore(_ postedDate: Date) -> Double {
        let daysSincePosted = Date().timeIntervalSince(postedDate) / (24 * 60 * 60)
        // Exponential decay: newer jobs score higher
        return exp(-daysSincePosted / 30.0) // Half-life of 30 days
    }

    private func calculateSourceScore(_ source: JobSource) -> Double {
        switch source {
        case .linkedin: return 1.0
        case .indeed: return 0.9
        case .glassdoor: return 0.8
        case .monster: return 0.7
        case .custom: return 0.5
        }
    }
}
