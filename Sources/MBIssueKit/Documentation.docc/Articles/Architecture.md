# Architecture

Understand how reports move from the overlay to Jira.

## Report flow

1. The overlay captures the visible host application while excluding its own window.
2. The composer accepts a separate title and description plus optional screenshots.
3. ``MBIssueStore`` validates and persists the report locally.
4. The Jira client creates a task through Jira Cloud REST API v3 using Atlassian Document Format for the description.
5. Screenshot attachments are uploaded with Jira's multipart attachment endpoint.
6. The local entry records its Jira key and URL. Failed work remains available for retry.

## Submission safety

The Jira issue is recorded locally before attachments are uploaded. A retry therefore continues against the same Jira
task instead of creating another task. Successfully uploaded filenames are also persisted so completed attachments are
not uploaded again.

## Data boundary

The create-task payload contains:

- The configured Jira project, issue type, and labels.
- The title written by the user.
- The description written by the user.

Screenshots selected by the user are sent as attachments. No application logs, TCA actions, navigation state, device
metadata, build information, or automatically generated technical description is collected.

## Test strategy

The package uses Swift Testing rather than XCTest. Domain validation, configuration normalization, payload mapping,
authentication headers, attachment requests, and persistence recovery are covered with deterministic tests. New
behavior should begin with a failing `@Test`, followed by the smallest implementation that makes it pass.
