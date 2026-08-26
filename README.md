# MBIssueKit

`MBIssueKit` is an iOS development tool for creating focused issue-tracker tasks without leaving the host application.

It provides a draggable overlay, a modern title/description composer, selectable severity, screenshot capture, image
annotation, technical runtime context, local retry storage, detailed report history, ZIP export, and authenticated
submission through the host application's backend. Reports can be saved as local drafts, selected together, and
submitted as separate tasks in one batch action. It never collects application logs, network payloads, or
state-management actions.

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

Configure the host application's provider-neutral issue-reporting gateway. Provider credentials and routing stay on
the server. For a backend that authorizes each reporter interactively, also provide a device-only session store:

```swift
let reporterSessionStore = MBIssueKeychainReporterSessionStore(
    service: Bundle.main.bundleIdentifier! + ".MBIssueKit"
)
let reporterAuthentication = try MBIssueReporterAuthenticationConfiguration(
    callbackURLScheme: "myapp-mbissue",
    sessionStore: reporterSessionStore
)
let gateway = try MBIssueGatewayConfiguration(
    baseURL: URL(string: "https://api.example.com")!,
    displayName: "Sonex issue reporting",
    reporterAuthentication: reporterAuthentication,
    accessTokenProvider: {
        guard let token = Session.shared.accessToken else {
            throw SessionError.notAuthenticated
        }
        return token
    }
)

MBIssueKit.configure(MBIssueKitConfiguration(
    gateway: gateway,
    environment: "staging",
    additionalContext: ["API cluster": "staging-eu"]
))
```

Use the shake gesture to toggle only the floating bar. The user opens the composer from the bar:

```swift
MBIssueKit.toggle()
```

`accessTokenProvider` is evaluated for every submission, so refreshed host-session tokens are used automatically. The
package never accepts or stores a provider access/refresh token, API token, project key, work-item type, label, or
priority mapping. The backend selects Jira, Azure DevOps, or another adapter and authenticates the host session before
creating an issue. Short-lived reporter sessions are renewed silently through the authenticated backend and a rejected
report is retried at most once with the same idempotency key. Interactive provider login is required again only when the
server-side user/device binding or provider grant is unavailable or revoked. MBIssueKit therefore does not change when
the destination board or provider changes.

Technical context includes the current screen/controller and navigation stack, application version/build, bundle,
environment, OS, device identifier, architecture, appearance, locale, and screen size. The composer shows this data
before submission. Reports can be inspected later and exported as a ZIP containing `report.md`, `metadata.json`, and
screenshots. Provider credentials are never included in the app or ZIP.

In the composer, **Save Draft** persists the report without contacting the backend. From **Issue reports**, choose the
selection control, select any pending or failed reports, and use **Create Selected**. Each report is sent as an
independent request and creates its own tracker task. Submitted and in-flight reports cannot be selected; a failure remains
attached to only that local report and can be retried without resubmitting successful entries.

## Development

The test suite uses Swift Testing and follows TDD. Run it with:

```sh
swift test
```

DocC documentation is included in the package and is verified by CI.

## License

MBIssueKit is available under the MIT license. See `LICENSE` for details.
