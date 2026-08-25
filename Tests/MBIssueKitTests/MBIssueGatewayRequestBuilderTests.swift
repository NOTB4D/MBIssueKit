import Foundation
@testable import MBIssueKit
import Testing

@Suite("Issue gateway requests")
struct MBIssueGatewayRequestBuilderTests {
    @Test("Submission uses the authenticated Sonex gateway multipart contract")
    func buildsMultipartRequest() throws {
        let configuration = try MBIssueGatewayConfiguration(
            baseURL: #require(URL(string: "https://api.sonex.example")),
            accessTokenProvider: { "unused-in-builder" }
        )
        let entry = try fixtureEntry()

        let request = try MBIssueGatewayRequestBuilder.submit(
            entry: entry,
            screenshots: [
                .init(fileName: "screen.png", mimeType: "image/png", data: Data("image".utf8)),
            ],
            configuration: configuration,
            accessToken: "sonex-access-token",
            reporterSessionToken: "reporter-session-token"
        )

        #expect(request.url?.absoluteString == "https://api.sonex.example/issue-reporting/api/v1/reports")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sonex-access-token")
        #expect(request.value(forHTTPHeaderField: "X-MBIssue-Reporter-Session") == "Bearer reporter-session-token")
        #expect(request.value(forHTTPHeaderField: "Idempotency-Key") == entry.id.uuidString)
        #expect(request.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data; boundary=") == true)

        let body = try #require(request.httpBody.flatMap { String(data: $0, encoding: .utf8) })
        #expect(body.contains("name=\"report\""))
        // MultipartKit/Vapor requires [] even when the array contains one file.
        #expect(body.contains("name=\"attachments[]\"; filename=\"screen.png\""))
        #expect(!body.contains("name=\"attachments\"; filename="))
        #expect(body.contains("Gateway title"))
        #expect(body.contains("Gateway description"))
        #expect(body.contains("\"severity\":\"major\""))
        #expect(!body.localizedCaseInsensitiveContains("apiToken"))
        #expect(!body.localizedCaseInsensitiveContains("jira"))
        #expect(!body.contains("reporter-session-token"))
    }

    private func fixtureEntry() throws -> MBIssueEntry {
        let draft = try MBIssueDraft(
            title: "Gateway title",
            description: "Gateway description",
            severity: .major,
            technicalContext: .init(
                screenName: "Home",
                viewControllerName: "UIHostingController",
                navigationStack: ["Home"],
                appName: "Sonex",
                bundleIdentifier: "com.sonex.app",
                appVersion: "1.2.3",
                buildNumber: "45",
                osVersion: "26.5",
                deviceModel: "iPhone",
                deviceIdentifier: "iPhone18,1",
                architecture: "arm64",
                environment: "development",
                locale: "tr_TR",
                isDarkMode: true,
                screenSize: "430x932 @3x",
                additional: [:]
            )
        ).validated()
        return MBIssueEntry(
            id: UUID(uuidString: "C7FB2F80-9CF6-4E18-928A-6AE08390DDEC")!,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            title: draft.title,
            description: draft.description,
            severity: draft.severity,
            technicalContext: draft.technicalContext,
            screenshotFileNames: ["screen.png"]
        )
    }
}
