@testable import MBIssueKit
import Testing

@Suite("Issue overlay toggle plan")
struct MBIssueTogglePlanTests {
    @Test("A hidden overlay is installed without presenting the composer")
    func installsHiddenOverlay() {
        let plan = MBIssueTogglePlan(isConfigured: true, isInstalled: false)

        #expect(plan.step == .install)
    }

    @Test("A visible overlay is removed")
    func removesVisibleOverlay() {
        let plan = MBIssueTogglePlan(isConfigured: true, isInstalled: true)

        #expect(plan.step == .remove)
    }

    @Test("An unconfigured overlay ignores the trigger")
    func ignoresUnconfiguredOverlay() {
        let plan = MBIssueTogglePlan(isConfigured: false, isInstalled: false)

        #expect(plan.step == nil)
    }
}
