import Foundation

struct MBIssueBatchSelection: Equatable, Sendable {
    private(set) var selectedIDs: Set<UUID> = []

    var isEmpty: Bool {
        selectedIDs.isEmpty
    }

    static func eligibleIDs(in entries: [MBIssueEntry]) -> Set<UUID> {
        Set(entries.compactMap { entry in
            switch entry.jiraStatus {
            case .notSubmitted, .failed:
                entry.id
            case .submitting, .submitted:
                nil
            }
        })
    }

    mutating func toggle(_ id: UUID, eligibleIDs: Set<UUID>) {
        guard eligibleIDs.contains(id) else { return }
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    mutating func selectAll(eligibleIDs: Set<UUID>) {
        selectedIDs = eligibleIDs
    }

    mutating func reconcile(eligibleIDs: Set<UUID>) {
        selectedIDs.formIntersection(eligibleIDs)
    }

    mutating func clear() {
        selectedIDs.removeAll()
    }
}
