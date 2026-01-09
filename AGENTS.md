# AGENTS.md - Trumann Project Standards

## OVERVIEW
* Automated job-hunting engine: intelligent sourcing, ranking, and document generation.
* Priority: elegant, functional-first Swift with extreme privacy-by-design.

## STRUCTURE
* `Shared/Core`: Domain primitives, shared value types, foundational logic.
* `Ingestion`: Sourcing adapters, raw data parsers, stream processing.
* `Ranking`: ATS-aware matching algorithms, scoring heuristics.
* `Generation`: Template engine for CVs, cover letters, and application metadata.
* `Tracking/Consent`: Compliance orchesßtration, state persistence, ATT gating.
* `Adapters`: Third-party API clients, database interfaces, external IO.

## STANDARDS
* Functional-first: Immutable state by default, value types (`struct`, `enum`).
* Logic: Pure functions for domain transformations; side effects isolated to Adapters.
* DI: Dependency inversion via protocols or closure-based injection (no singletons).
* Error Handling: Async/await with typed errors; domain-specific error enums.
* State: Structured concurrency (AsyncSequence, TaskGroup) for high-performance IO.
* Logging: OSLog with strict redaction; use `.private` or `.sensitive` for PII.

## PRIVACY & ATT
* ATT: `NSUserTrackingUsageDescription` required in `Info.plist`.
* Gating: Zero SDK initialization/tracking until `ATTrackingManager.requestTrackingAuthorization` returns `.authorized`.
* Privacy Manifest (`PrivacyInfo.xcprivacy`):
    * `NSPrivacyTracking`: Boolean flag for tracking status.
    * `NSPrivacyAccessedAPITypes`: Documented use of timestamps, file metadata, etc.
    * `NSPrivacyCollectedDataTypes`: Minimal scope; explicitly declare linking/purpose.
* Data Protection: `NSFileProtectionComplete` for all local storage.
* Secrets: No hardcoded keys; use Keychain for credentials/tokens.
* Data Rights:
    * Export SLA: Data available within 14 days of request.
    * Retrieval: Signed URLs valid for 6 hours max.
    * Deletion: Cascading hard-delete across all modules and third-party processors.

## TESTING
* Unit: Exhaustive coverage of pure domain logic.
* Property: Logic validation via `SwiftCheck` or similar for ranking/matching.
* Contract: Mock-based verification for all external `Adapters`.
* Integration: E2E flows from ingestion to generation.
* Determinism: Async flows must be deterministic; clock injection for time-sensitive logic.
* Golden Files: Snapshot testing for CV/Cover Letter template output.
* Redaction: Tests verifying that logs/exports do not leak sensitive fields.

## QUALITY GATES
* Formatting: `swift-format` enforced via pre-commit or CI.
* Linting: `SwiftLint` with custom rules for functional purity.
* Builds: Zero-warning policy; `-warnings-as-errors` enabled.
* Coverage: Minimum threshold (80%+) enforced on domain modules.

## CI
* Runner: macOS-latest for full Swift toolchain support.
* Cache: Persistent `.build` and SPM artifacts across runs.
* Pipeline: `Format` → `Lint` → `Build` → `Test` → `Coverage Report`.

## DOCS
* DocC: Required for all public API symbols and module interfaces.
* Module Guides: High-level architectural overview in each package directory.

## CONTRIBUTION CHECKLIST
- [ ] Run `swift-format` and `SwiftLint`.
- [ ] Verify unit tests pass and coverage is maintained.
- [ ] Update DocC for any public API changes.
- [ ] Update `PrivacyInfo.xcprivacy` if new data types are collected.
- [ ] Ensure any new secrets are handled via Keychain/Env.

## NEXT ACTIONS
* [x] Implement multi-target SwiftPM workspace with Core, Ingestion, Ranking, Generation, Tracking, Adapters.
* [x] Add PrivacyInfo.xcprivacy and ATT consent service.
* [x] Define core domain models and DI protocols.
* [x] Configure .swiftlint.yml and .swift-format.
* [x] Setup GitHub Actions CI with format/lint/build/test/coverage.
* [ ] Implement Ingestion module with HTTP/RSS parsers and AsyncSequence pipelines.
* [ ] Implement Ranking module with TF-IDF scoring.
* [ ] Implement Generation module with ATS-safe templates.
* [ ] Implement Tracking/Consent module with audit logs.
* [ ] Implement Adapters for LinkedIn/Indeed APIs.
* [ ] Add offline mode and sync reconciliation.
* [ ] Finalize DocC documentation and examples.
