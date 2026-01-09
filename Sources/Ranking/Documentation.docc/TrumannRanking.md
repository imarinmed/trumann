# ``TrumannRanking``

Intelligent job ranking using TF-IDF scoring and candidate profile matching.

## Overview

The Ranking module implements advanced job-candidate matching algorithms to surface the most relevant opportunities. It uses:

- **TF-IDF Scoring**: Term frequency-inverse document frequency for keyword relevance
- **Cosine Similarity**: Vector-based similarity between job descriptions and candidate profiles
- **Recency Decay**: Exponential time-based scoring to prioritize recent postings

## Topics

### Essentials

- ``JobRanker``
- ``RankedJob``
- ``TFIDFScorer``

### Scoring Algorithms

- ``CosineSimilarity``
- ``RecencyDecay``