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
        return nil
    }

    private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

struct MBIssueJiraCreateMetadataPage: Decodable, Sendable {
    let startAt: Int
    let maxResults: Int
    let total: Int
    let fields: [Field]

    private enum CodingKeys: String, CodingKey {
        case startAt
        case maxResults
        case total
        case fields
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fields = try container.decode([Field].self, forKey: .fields)
        startAt = try container.decodeIfPresent(Int.self, forKey: .startAt) ?? 0
        maxResults = try container.decodeIfPresent(Int.self, forKey: .maxResults) ?? fields.count
        total = try container.decodeIfPresent(Int.self, forKey: .total) ?? fields.count
    }

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
