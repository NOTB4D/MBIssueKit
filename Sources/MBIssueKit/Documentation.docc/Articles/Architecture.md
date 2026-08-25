# Architecture

Understand how reports move from the overlay through the host backend to Jira.

## Report flow

1. The overlay captures the visible host application while excluding its own window.
2. The composer accepts a separate title and description, severity, captured technical context, and optional screenshots.
3. ``MBIssueStore`` validates and persists the report locally. Saving a draft stops here.
4. The user can submit one report immediately or select multiple pending/failed reports from the local list.
5. The gateway client authenticates each report to the host backend with the user's current host-session token.
6. The backend maps the report to its server-owned Jira project, issue type, labels, and priority configuration.
7. The backend creates one Jira issue per local report and uploads that report's selected screenshots.
8. Each local entry independently records its Jira key and URL. Failed work remains available for retry without
   resubmitting entries that already succeeded.

## Submission safety

Every request includes the report UUID as an `Idempotency-Key`. A batch is a client-side sequence of independent
requests rather than a multi-issue Jira payload. The backend records each created Jira issue before uploading
attachments, so a retry continues against the same task instead of creating another task.

## Data boundary

The package sends:

- The title written by the user.
- The description written by the user.
- The selected severity.
- The technical context visible in the composer: screen/controller, navigation stack, application/build, environment,
  OS, device, architecture, appearance, locale, and screen size.

Screenshots selected by the user are sent as attachments. No application logs, network payloads, credentials, or
state-management actions are collected. A ZIP export contains Markdown, JSON metadata, and local screenshots, but never
contains Jira credentials. Jira project routing, labels, native priority names, and API credentials exist only on the
server.

## Test strategy

The package uses Swift Testing rather than XCTest. Domain validation, gateway configuration normalization, payload
mapping, authentication headers, attachment requests, and persistence recovery are covered with deterministic tests. New
behavior should begin with a failing `@Test`, followed by the smallest implementation that makes it pass.
