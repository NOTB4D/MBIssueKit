import Foundation

struct MBIssueJiraPriorityOption: Decodable, Equatable, Sendable {
    let id: String
    let name: String
}

enum MBIssueJiraPriorityResolver {
    static func resolve(
        severity: MBIssueSeverity,
        preferredName: String,
        options: [MBIssueJiraPriorityOption]
    ) -> String? {
        guard !options.isEmpty else { return nil }
        let preferredName = normalized(preferredName)
        if let exact = options.first(where: { normalized($0.name) == preferredName }) {
            return exact.id
        }
        let semanticName = normalized(severity.title)
        if let semantic = options.first(where: { normalized($0.name) == semanticName }) {
            return semantic.id
        }
        let index = switch severity {
        case .blocker: 0
        case .major: 1
        case .minor: 2
        case .cosmetic: 3
        }
        return options[min(index, options.count - 1)].id
    }

    private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

struct MBIssueJiraCreateMetadataPage: Decodable, Sendable {
    let fields: [Field]

    struct Field: Decodable, Sendable {
        let fieldID: String
        let key: String
        let allowedValues: [MBIssueJiraPriorityOption]

        private enum CodingKeys: String, CodingKey {
            case fieldID = "fieldId"
            case key
            case allowedValues
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            fieldID = try container.decodeIfPresent(String.self, forKey: .fieldID) ?? ""
            key = try container.decodeIfPresent(String.self, forKey: .key) ?? ""
            if fieldID == "priority" || key == "priority" {
                allowedValues = try container.decodeIfPresent(
                    [MBIssueJiraPriorityOption].self,
                    forKey: .allowedValues
                ) ?? []
            } else {
                allowedValues = []
            }
        }
    }
}
