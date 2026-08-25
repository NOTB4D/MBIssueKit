# ``MBIssueKit``

Create detailed, reproducible Jira tasks from an iOS app without collecting application logs.

## Overview

MBIssueKit installs a draggable overlay above a host application. A user can enter a dedicated title and description,
choose severity, review the technical context, annotate an automatically captured screenshot, add images from Photos,
and create a Jira task through the host application's backend. Reports are persisted locally before submission so
failed requests remain retryable. Local
reports have a detail screen and can be exported as a ZIP archive.

The report combines the user's text with the technical context shown in the composer. MBIssueKit does not
collect application logs, network payloads, credentials, or state-management actions such as TCA actions.

> Important: MBIssueKit authenticates only with the host application's short-lived session token. Jira API credentials
> and project configuration belong exclusively on the backend and must never ship in an iOS binary.

## Topics

### Getting Started

- <doc:Configuration>
- <doc:Architecture>

### Public API

- ``MBIssueKit``
- ``MBIssueKitConfiguration``
- ``MBIssueGatewayConfiguration``
- ``MBIssueDraft``
- ``MBIssueEntry``
- ``MBIssueSeverity``
- ``MBIssueTechnicalContext``
- ``MBIssueStore``

### Errors

- ``MBIssueConfigurationError``
- ``MBIssueValidationError``
- ``MBIssueGatewayError``
