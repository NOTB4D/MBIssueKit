@testable import MBIssueKit
import Testing

@Suite("Issue presentation plan")
struct MBIssuePresentationPlanTests {
    @Test("Explicit presentation installs the overlay before opening the composer")
    func installsThenPresentsWhenNeeded() {
        let plan = MBIssuePresentationPlan(
            isConfigured: true,
            isInstalled: false,
            isPresenting: false
        )

        #expect(plan.steps == [.capture, .install, .presentComposer])
    }

    @Test("An installed overlay opens the composer directly")
    func presentsFromInstalledOverlay() {
        let plan = MBIssuePresentationPlan(
            isConfigured: true,
            isInstalled: true,
            isPresenting: false
        )

        #expect(plan.steps == [.capture, .presentComposer])
    }

    @Test("An active presentation is not duplicated")
    func ignoresDuplicatePresentation() {
        let plan = MBIssuePresentationPlan(
            isConfigured: true,
            isInstalled: true,
            isPresenting: true
        )

        #expect(plan.steps.isEmpty)
    }

    @Test("An unconfigured reporter does not present")
    func ignoresUnconfiguredReporter() {
        let plan = MBIssuePresentationPlan(
            isConfigured: false,
            isInstalled: false,
            isPresenting: false
        )

        #expect(plan.steps.isEmpty)
    }
}
