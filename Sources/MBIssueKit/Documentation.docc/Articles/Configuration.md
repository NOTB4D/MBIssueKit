# Configuring MBIssueKit

Inject Jira settings from the host app before installing the overlay.

## Add the package

Add the package URL to the host application's Swift Package dependencies and link the `MBIssueKit` library product to
the app target.

## Configure Jira

Jira configuration is runtime configuration. Swift Package Manager does not provide a secure mechanism for passing
per-app credentials while resolving a dependency.

Create the configuration directly:

```swift
import MBIssueKit

#if DEBUG
let jira = try MBIssueJiraConfiguration(
    baseURL: URL(string: "https://your-company.atlassian.net")!,
    email: "developer@your-company.com",
    apiToken: jiraAPIToken,
    projectKey: "MOB",
    issueType: "Task",
    labels: ["mbissuekit", "ios"]
)

MBIssueKit.configure(MBIssueKitConfiguration(jira: jira))
MBIssueKit.install()
#endif
```

Or inject values through the host app's scheme, CI secrets, or configuration layer:

```swift
#if DEBUG
let jira = try MBIssueJiraConfiguration()
MBIssueKit.configure(MBIssueKitConfiguration(jira: jira))
MBIssueKit.install()
#endif
```

The environment initializer reads:

| Key | Required | Example |
| --- | --- | --- |
| `MBISSUEKIT_JIRA_BASE_URL` | Yes | `https://your-company.atlassian.net` |
| `MBISSUEKIT_JIRA_EMAIL` | Yes | `developer@your-company.com` |
| `MBISSUEKIT_JIRA_API_TOKEN` | Yes | Jira Cloud API token |
| `MBISSUEKIT_JIRA_PROJECT_KEY` | Yes | `MOB` |
| `MBISSUEKIT_JIRA_ISSUE_TYPE` | No | `Task` |
| `MBISSUEKIT_JIRA_LABELS` | No | `mbissuekit,ios` |

## Jira permissions

The account represented by the email and API token needs permission to browse the configured project, create the
configured issue type, and add attachments. Jira must also have attachments enabled.

## Remove the overlay

Call `MBIssueKit.remove()` when the development tool should no longer be available.
