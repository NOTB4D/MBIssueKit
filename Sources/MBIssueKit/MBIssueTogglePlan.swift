import Foundation

struct MBIssueTogglePlan: Equatable, Sendable {
    enum Step: Equatable, Sendable {
        case install
        case remove
    }

    let step: Step?

    init(isConfigured: Bool, isInstalled: Bool) {
        guard isConfigured else {
            step = nil
            return
        }
        step = isInstalled ? .remove : .install
    }
}
