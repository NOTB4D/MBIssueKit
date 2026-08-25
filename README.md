# MBIssueKit

`MBIssueKit` is an iOS development tool for creating focused Jira tasks without leaving the host application.

It provides a draggable overlay, a modern title/description composer, selectable severity, screenshot capture, image
annotation, technical runtime context, local retry storage, detailed report history, ZIP export, and authenticated
submission through the host application's backend. It never collects application logs, network payloads, or
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

Configure the host application's issue-reporting gateway. Jira credentials and field mappings stay on the server:

```swift
let gateway = try MBIssueGatewayConfiguration(
    baseURL: URL(string: "https://api.example.com")!,
    displayName: "Sonex issue reporting",
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
package never accepts or stores a Jira email, API token, project key, issue type, label, or priority mapping. The server
owns all Jira configuration and authenticates the incoming host session before creating an issue.

Technical context includes the current screen/controller and navigation stack, application version/build, bundle,
environment, OS, device identifier, architecture, appearance, locale, and screen size. The composer shows this data
before submission. Reports can be inspected later and exported as a ZIP containing `report.md`, `metadata.json`, and
screenshots. Jira credentials are never included in the app or ZIP.

## Development

The test suite uses Swift Testing and follows TDD. Run it with:

```sh
swift test
```

DocC documentation is included in the package and is verified by CI.

## License

MBIssueKit is available under the MIT license. See `LICENSE` for details.
