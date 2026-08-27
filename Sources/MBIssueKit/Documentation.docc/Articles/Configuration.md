# Configuring MBIssueKit

Configure Jira OAuth and routing for each host application, then start MBIssueKit once during application startup.

## Add the package

Add the package URL to Swift Package dependencies and link the `MBIssueKit` library product to the app target.

## Configure Jira

Create an Atlassian OAuth 2.0 (3LO) app. Register a custom callback URL and enable the scopes in
``MBIssueJiraConfiguration/defaultScopes``, including offline access, Jira read/write, sprint read/write, profile read,
and Personal Data Reporting. The `write:sprint:jira-software` scope is required to move a newly created task into the
configured board's active sprint.

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
    ],
    browserSessionPolicy: .shared
)

let configuration = try MBIssueKitConfiguration(
    jira: jira,
    environment: "staging",
    additionalContext: ["API cluster": "staging-eu"]
)

Task { @MainActor in
    try await MBIssueKit.start(configuration)
    MBIssueKit.install()
}
```

`projectKey`, `issueTypeID`, `boardID`, `sprintFieldID`, labels, and Jira priority preferences belong to the host app's
destination and are never fixed by MBIssueKit. The provider requires exactly one active sprint on the configured board.
Before creating the first issue, MBIssueKit reads Jira create metadata and resolves the selected severity to an allowed
priority ID. A matching configured name is preferred, followed by MBIssueKit's semantic severity name. Localized or
custom schemes should supply their exact Jira names; an unknown name is omitted rather than inferred from API ordering.
Create metadata is paginated until the priority field is found, and resolved values are cached for the provider session.

At startup, ``start(_:)`` moves the client secret into a device-only, non-synchronizing Keychain item. OAuth
access and rotating refresh tokens, accessible cloud selection, reporter identity, and Personal Data Reporting schedule
are stored in the same protected boundary. ``MBIssueProvider/disconnect()`` deletes the connected reporter session while
retaining the application-level client secret for the next login.

## Register the callback

Register the callback URL scheme, such as `myapp-mbissue`, under the app target's URL Types. The full callback URL must
exactly match the redirect URL configured in the Atlassian developer console.

Forward incoming URLs before the host application's own router. This also handles installed identity-provider app
handoffs that return directly to the application:

```swift
.onOpenURL { url in
    guard !MBIssueKit.handleOpenURL(url) else { return }
    appDeepLinkRouter.open(url)
}
```

The default `.shared` browser session can reuse Safari/Atlassian login state and supports installed-app handoffs.
Choose `.ephemeral` when the reporter must use an isolated browser session.

## Control the overlay

Forward the shake gesture to:

```swift
MBIssueKit.toggle()
```

This only shows or hides the floating bar. The composer opens when the reporter selects Report on that bar. Use
``present(referenceWindow:)`` only when the host app intentionally wants to open the composer immediately, and call
``remove()`` when the development tool should no longer be available.

`environment` and `additionalContext` are included in the technical context shown to the reporter. Do not place
credentials or request/response payloads in `additionalContext`.

## Supply another provider

Implement ``MBIssueProvider`` and pass it through the provider initializer:

```swift
let configuration = MBIssueKitConfiguration(
    provider: azureProvider,
    environment: "staging"
)
```

This preserves the report UI and local model while replacing authentication, destination routing, and submission.
