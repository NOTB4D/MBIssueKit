import Foundation

/// User-selected impact of an issue report.
public enum MBIssueSeverity: String, Codable, CaseIterable, Equatable, Hashable, Identifiable, Sendable {
    case blocker
    case major
    case minor
    case cosmetic

    public var id: Self {
        self
    }

    public var title: String {
        switch self {
        case .blocker: "Blocker"
        case .major: "Major"
        case .minor: "Minor"
        case .cosmetic: "Cosmetic"
        }
    }
}
