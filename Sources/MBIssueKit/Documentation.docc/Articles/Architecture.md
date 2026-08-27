# Architecture

Understand how reports move from the overlay to a provider while keeping UI, storage, and issue-tracker concerns separate.

## Report flow

1. The overlay captures the visible host application while excluding its own window.
2. The composer accepts a separate title and description, severity, visible technical context, and optional screenshots.
3. ``MBIssueStore`` validates and persists each report locally. Saving a draft stops here.
4. The reporter connects a Jira account through the system authentication session. State and exact callback validation
   protect the OAuth response.
5. ``MBIssueJiraProvider`` exchanges the code, selects the configured Jira site, reads the reporter profile, and persists
   the resulting authorization in a device-only Keychain item.
6. Before submission, an expired access token is renewed with the rotating refresh token and the replacement token pair
   is persisted atomically through the credential vault.
7. The Jira provider resolves exactly one active sprint for its configured board, creates one issue per local report, and
   uploads each selected screenshot as an attachment.
8. Each local entry independently records its provider ID, issue key, and URL. A failed report remains retryable without
   resubmitting entries that already succeeded.

All OAuth, profile, sprint, issue, attachment, and Personal Data Reporting traffic is sent through the package's
MBAsyncNetworking transport.

## Personal Data Reporting

The Jira authorization includes the `report:personal-data` scope. MBIssueKit records when the stored Jira profile was
retrieved and reports that account to Atlassian when its persisted cycle becomes due. It follows Atlassian's returned
`Cycle-Period`, delays after `Retry-After`, refreshes profile fields when requested, and removes local authorization when
Atlassian reports the account as closed.

## Data boundary

The Jira issue contains:

- The title and description entered by the reporter.
- The selected severity.
- The technical context shown in the composer: screen/controller, navigation stack, application/build, environment, OS,
  device, architecture, appearance, locale, and screen size.
- Screenshots explicitly selected by the reporter.

No application logs, network payloads, or state-management actions are collected. ZIP export contains Markdown, JSON
metadata, and local screenshots, but no provider credentials.

## Dependency boundaries

- Views depend on the reporter connection controller and report store, not a concrete issue tracker or networking API.
- The connection controller depends on ``MBIssueProvider`` and a provider-neutral web-authorizing boundary.
- ``MBIssueJiraProvider`` owns Jira-specific OAuth, routing, mapping, and response types.
- Keychain access is isolated behind the secure-store protocol and Jira credential vault.
- Network access is isolated behind a transport implemented with MBAsyncNetworking.
- Report models persist provider-neutral IDs and URLs; they contain no Jira-only fields.

Changing boards requires only a new ``MBIssueJiraConfiguration``. Adding Azure DevOps or another tracker requires a new
``MBIssueProvider`` implementation; capture, UI, local persistence, ZIP export, and batch orchestration remain unchanged.

## Test strategy

The package uses Swift Testing rather than XCTest and follows TDD. Tests cover configuration normalization, OAuth state
and callback validation, Keychain bootstrap, token rotation, active-sprint routing, issue and attachment requests,
Personal Data Reporting, provider-neutral persistence, validation, annotation interaction, and presentation behavior.
