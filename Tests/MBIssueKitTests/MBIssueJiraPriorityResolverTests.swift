@testable import MBIssueKit
import Testing

@Suite("Jira priority resolution")
struct MBIssueJiraPriorityResolverTests {
    private let localizedOptions = [
        MBIssueJiraPriorityOption(id: "1", name: "Kritik"),
        MBIssueJiraPriorityOption(id: "2", name: "Yüksek"),
        MBIssueJiraPriorityOption(id: "3", name: "Orta"),
        MBIssueJiraPriorityOption(id: "4", name: "Düşük"),
    ]

    @Test("A valid configured name is resolved to Jira's stable id")
    func resolvesConfiguredName() {
        #expect(MBIssueJiraPriorityResolver.resolve(
            severity: .major,
            preferredName: " yüksek ",
            options: localizedOptions
        ) == "2")
    }

    @Test("A semantic severity name is resolved when the configured name is stale")
    func resolvesSemanticSeverityName() {
        let options = [
            MBIssueJiraPriorityOption(id: "1", name: "Critical"),
            MBIssueJiraPriorityOption(id: "2", name: "Normal"),
            MBIssueJiraPriorityOption(id: "3", name: "Major"),
        ]

        #expect(MBIssueJiraPriorityResolver.resolve(
            severity: .major,
            preferredName: "High",
            options: options
        ) == "3")
    }

    @Test("An unknown configured name is not guessed from API ordering")
    func rejectsUnknownPriorityMapping() {
        #expect(MBIssueJiraPriorityResolver.resolve(
            severity: .blocker,
            preferredName: "Highest",
            options: localizedOptions
        ) == nil)
    }
}
