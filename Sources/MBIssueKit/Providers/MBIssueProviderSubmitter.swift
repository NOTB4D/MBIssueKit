import Foundation

/// Delivers local reports through the configured provider one at a time.
@MainActor
final class MBIssueProviderSubmitter {
    private let store: MBIssueStore
    private let provider: any MBIssueProvider

    init(store: MBIssueStore, provider: any MBIssueProvider) {
        self.store = store
        self.provider = provider
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
            let submission = try await provider.submit(
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
