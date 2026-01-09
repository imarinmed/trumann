import Testing
import Ranking
import Core
import Foundation

@Test func rankingWeights() {
    let weights = RankingWeights(titleWeight: 0.5, descriptionWeight: 0.3)
    #expect(weights.titleWeight == 0.5)
    #expect(weights.descriptionWeight == 0.3)
}

@Test func tfidfScorer() {
    let corpus = ["swift developer", "ios engineer", "software engineer"]
    let scorer = TFIDFScorer(corpus: corpus)

    let score = scorer.score(query: "swift", document: "swift developer")
    #expect(score > 0)
}

@Test func cosineSimilarity() {
    let sim = Ranking.cosineSimilarity([1, 2, 3], [1, 2, 3])
    #expect(sim == 1.0)

    let sim2 = Ranking.cosineSimilarity([1, 0], [0, 1])
    #expect(abs(sim2) < 0.01) // Orthogonal
}

@Test func jobRanker() {
    let ranker = JobRanker()
    let query = JobQuery(keywords: "swift ios")
    let job = Job(
        title: "iOS Developer",
        company: "Apple",
        description: "Swift development",
        postedDate: Date(),
        url: "https://apple.com",
        source: .linkedin
    )

    let ranked = ranker.rank(job, query: query)
    #expect(ranked.job.title == "iOS Developer")
    #expect(ranked.score > 0)
    #expect(ranked.explanation.contains("Title:"))
}

@Test func jobRankerDeterministic() {
    let ranker = JobRanker()
    let query = JobQuery(keywords: "engineer")
    let fixedDate = Date(timeIntervalSince1970: 1000000000)
    let job = Job(
        title: "Software Engineer",
        company: "Google",
        description: "Engineering role",
        postedDate: fixedDate,
        url: "https://google.com",
        source: .indeed
    )

    let ranked1 = ranker.rank(job, query: query)
    let ranked2 = ranker.rank(job, query: query)

    #expect(ranked1.score == ranked2.score)
    #expect(ranked1.explanation == ranked2.explanation)
}
