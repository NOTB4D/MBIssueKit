import Foundation
@testable import MBIssueKit
import Testing

@Suite("Issue batch selection")
struct MBIssueBatchSelectionTests {
    @Test("Only retryable reports are eligible for a batch")
    func eligibility() {
        let pending = entry(status: .notSubmitted)
        let failed = entry(status: .failed)
        let submitting = entry(status: .submitting)
        let submitted = entry(status: .submitted)

        let eligibleIDs = MBIssueBatchSelection.eligibleIDs(
            in: [pending, failed, submitting, submitted]
        )

        #expect(eligibleIDs == [pending.id, failed.id])
    }

    @Test("Select all and toggle never include an ineligible report")
    func selectionRules() {
        let first = UUID()
        let second = UUID()
        let submitted = UUID()
        let eligibleIDs: Set<UUID> = [first, second]
        var selection = MBIssueBatchSelection()

        selection.selectAll(eligibleIDs: eligibleIDs)
        selection.toggle(submitted, eligibleIDs: eligibleIDs)
        selection.toggle(first, eligibleIDs: eligibleIDs)

        #expect(selection.selectedIDs == [second])
    }

    @Test("Selection drops reports that become ineligible")
    func reconciliation() {
        let first = UUID()
        let second = UUID()
        var selection = MBIssueBatchSelection()
        selection.selectAll(eligibleIDs: [first, second])

        selection.reconcile(eligibleIDs: [second])

        #expect(selection.selectedIDs == [second])
    }

    private func entry(status: MBIssueSubmissionStatus) -> MBIssueEntry {
        MBIssueEntry(
            id: UUID(),
            createdAt: Date(),
            title: "Title",
            description: "Description",
            screenshotFileNames: [],
            submissionStatus: status
        )
    }
}
