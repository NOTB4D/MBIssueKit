# MBIssueKit

`MBIssueKit` is an iOS development tool for creating focused Jira tasks without leaving the host application.

It provides a draggable overlay, a modern title/description composer, screenshot capture, image annotation, local retry
storage, and direct Jira Cloud submission. Jira receives only the user's title and description plus screenshots the
user keeps or selects—no logs, TCA actions, navigation state, device metadata, or technical context.

## Requirements

- iOS 15 or later
- Swift 6.0 or later

## Installation

Add `MBIssueKit` to your project with Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/NOTB4D/MBIssueKit.git", branch: "develop")
]
```

Then add `MBIssueKit` to your target dependencies and import it:

```swift
import MBIssueKit
```

## Configuration

Configure Jira at runtime and install the overlay from development-only app startup code:

```swift
#if DEBUG
let jira = try MBIssueJiraConfiguration(
    baseURL: URL(string: "https://your-company.atlassian.net")!,
    email: "developer@your-company.com",
    apiToken: jiraAPIToken,
    projectKey: "MOB",
    issueType: "Task"
)

MBIssueKit.configure(MBIssueKitConfiguration(jira: jira))
MBIssueKit.install()
#endif
```

`MBIssueJiraConfiguration()` can alternatively read values injected by the host app:

- `MBISSUEKIT_JIRA_BASE_URL`
- `MBISSUEKIT_JIRA_EMAIL`
- `MBISSUEKIT_JIRA_API_TOKEN`
- `MBISSUEKIT_JIRA_PROJECT_KEY`
- `MBISSUEKIT_JIRA_ISSUE_TYPE` (optional, defaults to `Task`)
- `MBISSUEKIT_JIRA_LABELS` (optional, comma-separated)

Swift Package Manager cannot accept runtime secrets during dependency resolution. Keep API tokens out of source control
and use MBIssueKit only in protected development or QA builds.

## Development

The test suite uses Swift Testing and follows TDD. Run it with:

```sh
swift test
```

DocC documentation is included in the package and is verified by CI.

## License

MBIssueKit is available under the MIT license. See `LICENSE` for details.
