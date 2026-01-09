# ``TrumannIngestion``

Automated job ingestion from various sources with duplicate detection and normalization.

## Overview

The Ingestion module provides the core infrastructure for sourcing job postings from external APIs and feeds. It includes:

- **HTTP Client**: Protocol-based network abstraction
- **Feed Parsers**: RSS/Atom parsing with job extraction
- **Pipeline Processing**: Async stream-based job ingestion with duplicate detection
- **Data Normalization**: Consistent job data formatting

## Topics

### Essentials

- ``HTTPClient``
- ``FeedParser``
- ``JobIngestionPipeline``
- ``JobNormalizer``

### Feed Parsers

- ``RSSParser``
- ``RSSXMLParser``

### Errors

- ``DomainError``