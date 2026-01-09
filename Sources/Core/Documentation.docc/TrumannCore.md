# ``TrumannCore``

A functional-first Swift package for automated job hunting with extreme privacy-by-design.

## Overview

TrumannCore provides the foundational domain models and dependency injection framework for the Trumann job-hunting engine. Built with Swift 6 concurrency and structured concurrency patterns.

## Topics

### Domain Models
- ``Job``
- ``JobQuery``
- ``Profile``
- ``Application``
- ``Event``
- ``RankedJob``

### Dependency Injection
- ``Clock``
- ``UUIDGenerator``
- ``Logger``
- ``Storage``
- ``NetworkClient``
- ``ConsentService``

### Privacy & Consent
- ``ConsentState``
- ``LiveConsentService``
- ``TestConsentService``

## Architecture

TrumannCore follows functional programming principles:
- Immutable value types for domain models
- Protocol-based dependency injection
- Pure functions for business logic
- Isolated side effects in adapters

All domain types are `Sendable` for safe concurrency.