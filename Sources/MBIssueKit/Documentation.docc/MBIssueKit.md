# MBIssueKit

Create detailed Jira Cloud tasks from an iOS app without collecting application logs.

## Overview

MBIssueKit installs a draggable overlay above the host application. A reporter enters a dedicated title and description,
chooses severity, reviews captured technical context, annotates an automatically captured screenshot, and can add images
from Photos. Reports may be saved as drafts, inspected in detail, exported as ZIP archives, and submitted individually or
as a selected batch.

The built-in ``MBIssueJiraProvider`` performs Jira OAuth, active-sprint lookup, issue creation, and attachment upload
directly. It persists the supplied OAuth client secret, access and rotating refresh tokens, selected Jira cloud, and
reporter identity in device-only Keychain items. All provider network requests use MBAsyncNetworking.

The domain and UI layers depend on ``MBIssueProvider``. Another issue tracker can therefore be introduced as a provider
without changing capture, annotation, persistence, or batch-submission behavior.

The report contains the user's title and description, selected severity, visible technical context, and selected images.
MBIssueKit does not collect application logs, network payloads, or state-management actions such as TCA actions.

## Topics

### Getting Started

- <doc:Configuration>
- <doc:Architecture>

### Provider API

- ``start(_:)``
- ``install(referenceWindow:)``
- ``toggle(referenceWindow:)``
- ``present(referenceWindow:)``
- ``remove()``
- ``handleOpenURL(_:)``
- ``MBIssueKitConfiguration``
- ``MBIssueProvider``
- ``MBIssueJiraConfiguration``
- ``MBIssueJiraProvider``
- ``MBIssueTrackerProvider``
- ``MBIssueReporterConnection``
- ``MBIssueBrowserSessionPolicy``

### Report API

- ``MBIssueDraft``
- ``MBIssueEntry``
- ``MBIssueSeverity``
- ``MBIssueTechnicalContext``
- ``MBIssueStore``

### Errors

- ``MBIssueConfigurationError``
- ``MBIssueValidationError``
- ``MBIssueProviderError``
