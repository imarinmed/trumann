# ``TrumannTracking``

Privacy-compliant user consent and application tracking management.

## Overview

The Tracking module handles user consent for data collection and tracks job application progress while maintaining privacy compliance. Features include:

- **Consent Orchestration**: ATT-compliant consent management with state machines
- **Audit Logging**: Redacted event logging for analytics and compliance
- **Application Tracking**: Status management for job applications
- **Privacy Gates**: Automatic gating of features based on consent status

## Topics

### Essentials

- ``ConsentService``
- ``AuditLogger``
- ``ApplicationTracker``

### Consent Management

- ``ConsentState``
- ``LiveConsentService``

### Analytics

- ``Event``
- ``EventType``