# MBIssueKit

`MBIssueKit` is an iOS development SDK for creating Jira Cloud issues without leaving the host application.

It provides a draggable floating bar, a title/description composer, severity selection, screenshot capture and annotation,
technical runtime context, local drafts and retry history, batch submission, report details, and ZIP export. It does not
collect application logs, network payloads, or state-management actions.

## Requirements

- iOS 15 or later
- Swift 6.0 or later

## Distribution

Application teams consume the closed binary package, not this development repository. A version tag runs
`Release XCFramework`, which produces a library-evolution-enabled `MBIssueKit.xcframework.zip`, dSYMs, and its SwiftPM
checksum. Publish that artifact through the dedicated distribution repository using
[`Distribution/Package.swift.template`](Distribution/Package.swift.template). The companion dependency target links
MBAsyncNetworking and MobKitCore without exposing MBIssueKit source files.

SDK development remains in this repository so its Swift Testing and DocC sources stay available to the SDK team.

## Installation

Add the binary distribution repository with Swift Package Manager and link the `MBIssueKit` product to the application
target:

```swift
dependencies: [
    .package(url: "<MBIssueKit binary distribution repository>", from: "1.0.0")
]
```

MBIssueKit uses
[`MBAsyncNetworkingXCFramework`](https://github.com/mobven/MBAsyncNetworkingXCFramework) for all provider network traffic.

## Jira setup

Create an Atlassian OAuth 2.0 (3LO) app and register the same custom callback URL used by the iOS application. Supply
project, issue type, board, sprint field, labels, and priority mappings per host app; these values are not hardcoded in
the SDK.

```swift
import MBIssueKit

let jira = try MBIssueJiraConfiguration(
    clientID: AppConfiguration.jiraClientID,
    clientSecret: AppConfiguration.jiraClientSecret,
    callbackURL: URL(string: "myapp-mbissue://oauth/callback")!,
    siteURL: URL(string: "https://company.atlassian.net")!,
    projectKey: "MOBILE",
    issueTypeID: "10001",
    boardID: 42,
    sprintFieldID: "customfield_10020",
    labels: ["ios"],
    priorityNames: [
        .blocker: "Highest",
        .major: "High",
        .minor: "Medium",
    ]
)

let issueKitConfiguration = try MBIssueKitConfiguration(
    jira: jira,
    environment: "staging",
    additionalContext: ["API cluster": "staging-eu"]
)

Task { @MainActor in
    try await MBIssueKit.start(issueKitConfiguration)
    MBIssueKit.install()
}
```

`start(_:)` transfers the supplied client secret to a device-only, non-synchronizing Keychain item. Jira access tokens,
rotating refresh tokens, the selected Jira cloud, and the reporter profile are also persisted in Keychain. OAuth,
active-sprint lookup, issue creation, screenshot upload, token renewal, and Atlassian Personal Data Reporting run inside
the package.

Register the callback scheme in the app target and forward callbacks before the app's own deep-link router:

```swift
.onOpenURL { url in
    guard !MBIssueKit.handleOpenURL(url) else { return }
    appDeepLinkRouter.open(url)
}
```

Use the shake gesture to toggle only the floating bar. The user opens the composer from the bar:

```swift
MBIssueKit.toggle()
```

Each selected local report creates a separate Jira task in the configured active sprint. Screenshots are uploaded as
attachments. Failed reports remain independently retryable, and exported ZIP files never contain provider credentials.

## Extending providers

The UI, capture, persistence, and batch layers depend on the provider-neutral `MBIssueProvider` protocol. A future Azure
DevOps or other issue-tracker adapter can implement that boundary and be passed to `MBIssueKitConfiguration(provider:)`
without changing the report workflow.

## Development

The test suite uses Swift Testing and follows TDD:

```sh
swift test
```

DocC documentation is included and built by CI.

Because MBAsyncNetworkingXCFramework is private, CI and binary-release workflows require a fine-grained repository
secret named `MOBVEN_PACKAGES_TOKEN` with read-only Contents access to `mobven/MBAsyncNetworkingXCFramework`.

## License

MBIssueKit is available under the MIT license. See `LICENSE` for details.
