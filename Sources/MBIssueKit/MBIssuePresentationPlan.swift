import Foundation

struct MBIssuePresentationPlan: Equatable, Sendable {
    enum Step: Equatable, Sendable {
        case capture
        case install
        case presentComposer
    }

    let steps: [Step]

    init(
        isConfigured: Bool,
        isInstalled: Bool,
        isPresenting: Bool
    ) {
        guard isConfigured, !isPresenting else {
            steps = []
            return
        }

        steps = isInstalled
            ? [.capture, .presentComposer]
            : [.capture, .install, .presentComposer]
    }
}
