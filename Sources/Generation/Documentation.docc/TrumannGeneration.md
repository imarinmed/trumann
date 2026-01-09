# ``TrumannGeneration``

Automated CV and cover letter generation using AI with ATS optimization.

## Overview

The Generation module creates tailored application materials using large language models. Key features include:

- **LLM Integration**: OpenAI API client with fallback to stub responses
- **ATS Optimization**: Resume formatting optimized for applicant tracking systems
- **Redaction**: Automatic removal of sensitive information from generated content
- **Template Engine**: Structured prompts for consistent, professional output

## Topics

### Essentials

- ``LLMAdapter``
- ``LiveLLMAdapter``
- ``TemplateEngine``

### CV Generation

- ``CVGenerator``
- ``CoverLetterGenerator``