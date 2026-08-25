# Configuring MBIssueKit

Connect MBIssueKit to an authenticated endpoint owned by the host application.

## Add the package

Add the package URL to the host application's Swift Package dependencies and link the `MBIssueKit` library product to
the app target.

## Configure the gateway

MBIssueKit never accepts provider credentials or field mappings. Configure only the host application's HTTPS backend
and provide the signed-in user's current Sonex access token at request time.

Create the configuration directly:

```swift
import MBIssueKit

let reporterStore = MBIssueKeychainReporterSessionStore(
    service: Bundle.main.bundleIdentifier! + ".MBIssueKit"
)
let reporterAuthentication = try MBIssueReporterAuthenticationConfiguration(
    callbackURLScheme: "sonex-mbissue",
    sessionStore: reporterStore
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

The provider is asynchronous and runs immediately before a submission. It can therefore read a refreshed access token
from the host app's keychain or session store. Do not return an issue-tracker token from this closure.

Register the same custom URL scheme in the app target. Interactive login uses an ephemeral system authentication
session. The issue tracker's authorization code and access/refresh tokens terminate at the backend; the callback URL
returning to the app contains no secret. Only a backend-issued, revocable reporter session is stored in the device-only,
non-synchronizing Keychain item.

## Toggle the overlay

Forward a shake notification to ``MBIssueKit/toggle(referenceWindow:)``:

```swift
MBIssueKit.toggle()
```

This only shows or hides the floating bar. The composer opens when the user chooses Report on that bar.

`environment` and `additionalContext` are non-secret values included in the technical context shown to the user and
sent to the reporting backend. Never put tokens, personal data, or request/response payloads in `additionalContext`.

## Server contract

The package posts multipart data to `/issue-reporting/api/v1/reports`, using the host token as a Bearer credential and
the report UUID as `Idempotency-Key`. If reporter authentication is configured it also sends the opaque session in
`X-MBIssue-Reporter-Session`; never in the request body. The backend validates both sessions, owns provider OAuth
credentials and routing, creates the issue, and uploads selected screenshots. The response contains `providerID`,
`providerDisplayName`, `issueID`, `issueKey`, and `issueURL`.

## Remove the overlay

Call ``MBIssueKit/remove()`` when the development tool should no longer be available.
