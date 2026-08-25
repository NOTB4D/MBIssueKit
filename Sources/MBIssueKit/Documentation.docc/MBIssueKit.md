# ``MBIssueKit``

Create detailed, reproducible issue-tracker tasks from an iOS app without collecting application logs.

## Overview

MBIssueKit installs a draggable overlay above a host application. A user can enter a dedicated title and description,
choose severity, review the technical context, annotate an automatically captured screenshot, add images from Photos,
and create a task through the host application's backend. Reports can be saved locally as drafts and later selected
for batch submission. Every selected report creates a separate task, while failures remain independently retryable.
Local reports have a detail screen and can be exported as a ZIP archive.

The report combines the user's text with the technical context shown in the composer. MBIssueKit does not
collect application logs, network payloads, credentials, or state-management actions such as TCA actions.

> Important: MBIssueKit receives only the host application's short-lived session token and, when interactive reporter
> authorization is enabled, a revocable opaque backend session. Issue-tracker OAuth/API credentials and routing belong
> exclusively on the backend and must never ship in an iOS binary.

## Topics

### Getting Started

- <doc:Configuration>
- <doc:Architecture>

### Public API

- ``MBIssueKit``
- ``MBIssueKitConfiguration``
- ``MBIssueGatewayConfiguration``
- ``MBIssueReporterAuthenticationConfiguration``
- ``MBIssueReporterSessionStoring``
- ``MBIssueKeychainReporterSessionStore``
- ``MBIssueTrackerProvider``
- ``MBIssueReporterConnection``
- ``MBIssueDraft``
- ``MBIssueEntry``
- ``MBIssueSeverity``
- ``MBIssueTechnicalContext``
- ``MBIssueStore``

### Errors

- ``MBIssueConfigurationError``
- ``MBIssueValidationError``
- ``MBIssueGatewayError``
