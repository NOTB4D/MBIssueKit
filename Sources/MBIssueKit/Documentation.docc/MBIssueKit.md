# ``MBIssueKit``

Create focused Jira tasks from an iOS app without collecting application logs or technical context.

## Overview

MBIssueKit installs a draggable overlay above a host application. A user can enter a dedicated title and description,
review or annotate an automatically captured screenshot, add images from Photos, and create a Jira task. Reports are
persisted locally before submission so failed requests remain retryable.

The Jira description contains only text written by the user. MBIssueKit does not add navigation state, architecture
details, TCA actions, device metadata, or application logs.

> Important: MBIssueKit authenticates with a Jira Cloud email and API token. Use it only in protected development or
> QA builds, inject credentials at runtime, and never commit a token to source control.

## Topics

### Getting Started

- <doc:Configuration>
- <doc:Architecture>

### Public API

- ``MBIssueKit``
- ``MBIssueKitConfiguration``
- ``MBIssueJiraConfiguration``
- ``MBIssueDraft``
- ``MBIssueEntry``
- ``MBIssueStore``

### Errors

- ``MBIssueConfigurationError``
- ``MBIssueValidationError``
- ``MBIssueJiraError``
