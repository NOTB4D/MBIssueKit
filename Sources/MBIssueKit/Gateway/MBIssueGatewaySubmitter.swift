import Foundation

@MainActor
final class MBIssueGatewaySubmitter {
    private let store: MBIssueStore
    private let client: MBIssueGatewayClient

    init(store: MBIssueStore, client: MBIssueGatewayClient) {
        self.store = store
        self.client = client
    }

    func submit(ids: [UUID]) async {
        for id in ids {
            guard !Task.isCancelled else { return }
            await submit(id: id)
        }
    }

    private func submit(id: UUID) async {
        guard let entry = store.entry(id: id), entry.submissionStatus != .submitted else {
            return
        }
        store.updateSubmissionState(id: id, status: .submitting, submission: entry.submission)
        do {
            let submission = try await client.submit(
                entry: entry,
                screenshotURLs: store.screenshotURLs(for: entry)
            )
            store.updateSubmissionState(
                id: id,
                status: .submitted,
                submission: submission,
                message: "\(submission.issueKey) created in \(submission.providerDisplayName)."
            )
        } catch is CancellationError {
            store.updateSubmissionState(
                id: id,
                status: .failed,
                submission: store.entry(id: id)?.submission,
                message: "Submission was cancelled."
            )
        } catch {
            store.updateSubmissionState(
                id: id,
                status: .failed,
                submission: store.entry(id: id)?.submission,
                message: error.localizedDescription
            )
        }
    }
}
