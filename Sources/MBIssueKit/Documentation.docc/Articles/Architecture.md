# Architecture

Understand how reports move from the overlay through a host backend to the selected issue tracker.

## Report flow

1. The overlay captures the visible host application while excluding its own window.
2. The composer accepts a separate title and description, severity, captured technical context, and optional screenshots.
3. ``MBIssueStore`` validates and persists the report locally. Saving a draft stops here.
4. The user can submit one report immediately or select multiple pending/failed reports from the local list.
5. When required, the reporter authorizes their own tracker identity through the system browser. MBIssueKit retains only
   a revocable backend session in a device-only Keychain item; provider OAuth tokens never reach iOS.
6. The browser callback and a proof-bound backend status poll race to completion. This lets an installed identity-provider
   app complete the server callback even when it does not return control to the system authentication sheet.
7. If that short-lived reporter session expires, the gateway silently replaces it through the authenticated host backend.
   Interactive provider authorization is shown again only when the server-side user/device binding or provider grant is revoked.
8. The gateway client authenticates each report to the host backend with the current host and reporter sessions.
9. The backend's selected provider adapter maps the report to server-owned project/board, work-item type, labels, and
   priority configuration.
10. The backend creates one provider issue per local report and uploads that report's selected screenshots.
11. Each local entry independently records its provider ID, issue key, and URL. Failed work remains available for retry without
   resubmitting entries that already succeeded.

## Submission safety

Every request includes the report UUID as an `Idempotency-Key`. A batch is a client-side sequence of independent
requests rather than a provider-specific multi-issue payload. The backend records each created issue before uploading
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
contains provider credentials. Project/board routing, labels, native priority names, and OAuth/API credentials exist
only on the server.

## Dependency boundaries

- Views depend on the reporter connection controller and report store, not URLSession or a concrete tracker.
- The connection controller depends on the `MBIssueReportingGateway` and `MBIssueWebAuthorizing` protocols.
- Authorization recovery depends only on provider-neutral challenge states; it contains no Jira-specific branch or URL.
- The gateway speaks only provider-neutral DTOs and persists through `MBIssueReporterSessionStoring`.
- Reporter-session renewal is single-flight and retries a rejected report at most once with the rotated opaque session.
- The host backend selects concrete Jira, Azure DevOps, or future adapters behind its own provider protocol.

Changing boards is deployment configuration. Adding a tracker requires a backend adapter and registration in the
backend composition root; MBIssueKit's domain, UI, persistence, and public configuration remain unchanged.

## Test strategy

The package uses Swift Testing rather than XCTest. Domain validation, gateway configuration normalization, payload
mapping, authentication headers, provider switching, attachment requests, and persistence recovery are covered with deterministic tests. New
behavior should begin with a failing `@Test`, followed by the smallest implementation that makes it pass.
