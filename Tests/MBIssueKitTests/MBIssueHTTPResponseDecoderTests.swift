import Foundation
@testable import MBIssueKit
import Testing

@Suite("HTTP response decoding")
struct MBIssueHTTPResponseDecoderTests {
    @Test("Jira field errors are preserved for diagnosis")
    func preservesJiraFieldErrors() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "errorMessages": ["Issue could not be created."],
            "errors": ["customfield_10020": "Field cannot be set."],
        ])
        let response = MBIssueRawNetworkResponse(statusCode: 400, data: data, headers: [:])

        #expect(throws: MBIssueProviderError.server(
            statusCode: 400,
            message: "Issue could not be created. customfield_10020: Field cannot be set."
        )) {
            let _: EmptyResponse = try MBIssueHTTPResponseDecoder.decode(
                response,
                as: EmptyResponse.self
            )
        }
    }
}

private struct EmptyResponse: Decodable, Sendable {}
