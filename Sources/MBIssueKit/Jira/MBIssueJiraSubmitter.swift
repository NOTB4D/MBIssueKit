import Foundation

@MainActor
final class MBIssueJiraSubmitter {
    private let store: MBIssueStore
    private let client: MBIssueJiraClient

    init(store: MBIssueStore, client: MBIssueJiraClient) {
        self.store = store
        self.client = client
    }

    func submit(ids: [UUID]) async {
        for id in ids {
            guard !Task.isCancelled else {
                return
            }
            await submit(id: id)
        }
    }

    private func submit(id: UUID) async {
        guard let entry = store.entry(id: id), entry.jiraStatus != .submitted else {
            return
        }
        store.updateJiraState(
            id: id,
            status: .submitting,
            submission: entry.jiraSubmission,
            message: nil
        )

        do {
            let submission = try await issueSubmission(for: entry)
            let completed = try await uploadPendingScreenshots(
                for: entry,
                submission: submission
            )
            store.updateJiraState(
                id: id,
                status: .submitted,
                submission: completed,
                message: "\(completed.issueKey) created in Jira."
            )
        } catch is CancellationError {
            let submission = store.entry(id: id)?.jiraSubmission
            store.updateJiraState(
                id: id,
                status: .failed,
                submission: submission,
                message: "Submission was cancelled."
            )
        } catch {
            let submission = store.entry(id: id)?.jiraSubmission
            store.updateJiraState(
                id: id,
                status: .failed,
                submission: submission,
                message: error.localizedDescription
            )
        }
    }

    private func issueSubmission(for entry: MBIssueEntry) async throws -> MBIssueEntry.JiraSubmission {
        if let existing = entry.jiraSubmission {
            return existing
        }
        let draft = try MBIssueDraft(
            title: entry.title,
            description: entry.description
        ).validated()
        let submission = try await client.createIssue(draft: draft)
        store.updateJiraState(
            id: entry.id,
            status: .submitting,
            submission: submission,
            message: "\(submission.issueKey) created. Uploading screenshots…"
        )
        return submission
    }

    private func uploadPendingScreenshots(
        for entry: MBIssueEntry,
        submission: MBIssueEntry.JiraSubmission
    ) async throws -> MBIssueEntry.JiraSubmission {
        var submission = submission
        for url in store.screenshotURLs(for: entry) {
            try Task.checkCancellation()
            guard !submission.uploadedFileNames.contains(url.lastPathComponent) else {
                continue
            }
            try await client.addAttachment(at: url, to: submission.issueKey)
            submission.uploadedFileNames.append(url.lastPathComponent)
            store.updateJiraState(
                id: entry.id,
                status: .submitting,
                submission: submission,
                message: "Uploading screenshots…"
            )
        }
        return submission
    }
}
