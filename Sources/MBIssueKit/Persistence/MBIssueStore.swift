import Combine
import Foundation

/// Stores issue drafts and screenshots locally until provider submission succeeds.
@MainActor
public final class MBIssueStore: ObservableObject {
    public static let shared = MBIssueStore()

    @Published public private(set) var entries: [MBIssueEntry] = []

    private let fileManager: FileManager
    private let rootURL: URL?

    private var entriesFileURL: URL? {
        rootURL?.appendingPathComponent("entries.json")
    }

    private var screenshotsDirectoryURL: URL? {
        rootURL?.appendingPathComponent("screenshots", isDirectory: true)
    }

    private convenience init() {
        let manager = FileManager.default
        let applicationSupport = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        self.init(
            fileManager: manager,
            rootURL: applicationSupport?.appendingPathComponent("MBIssueKit", isDirectory: true)
        )
    }

    init(fileManager: FileManager = .default, rootURL: URL?) {
        self.fileManager = fileManager
        self.rootURL = rootURL
        prepareDirectories()
        load()
    }

    /// Adds a validated report and PNG screenshots to local storage.
    @discardableResult
    public func add(
        draft: MBIssueDraft,
        screenshotData: [Data]
    ) throws -> MBIssueEntry {
        let draft = try draft.validated()
        let id = UUID()
        let fileNames = try persistScreenshots(screenshotData, entryID: id)
        let entry = MBIssueEntry(
            id: id,
            createdAt: Date(),
            title: draft.title,
            description: draft.description,
            severity: draft.severity,
            technicalContext: draft.technicalContext,
            screenshotFileNames: fileNames
        )
        entries.insert(entry, at: 0)
        persist()
        return entry
    }

    public func delete(_ entry: MBIssueEntry) {
        entries.removeAll { $0.id == entry.id }
        removeScreenshots(named: entry.screenshotFileNames)
        persist()
    }

    public func deleteAll() {
        entries.forEach { removeScreenshots(named: $0.screenshotFileNames) }
        entries.removeAll()
        persist()
    }

    public func entry(id: UUID) -> MBIssueEntry? {
        entries.first { $0.id == id }
    }

    public func screenshotURLs(for entry: MBIssueEntry) -> [URL] {
        guard let directory = screenshotsDirectoryURL else {
            return []
        }
        return entry.screenshotFileNames.map { directory.appendingPathComponent($0) }
    }

    func updateSubmissionState(
        id: UUID,
        status: MBIssueSubmissionStatus,
        submission: MBIssueSubmissionReceipt? = nil,
        message: String? = nil
    ) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            return
        }
        entries[index].submissionStatus = status
        if let submission {
            entries[index].submission = submission
        }
        entries[index].submissionMessage = message
        persist()
    }

    private func prepareDirectories() {
        guard let rootURL else {
            return
        }
        try? fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        if let screenshotsDirectoryURL {
            try? fileManager.createDirectory(at: screenshotsDirectoryURL, withIntermediateDirectories: true)
        }
    }

    private func persistScreenshots(_ screenshots: [Data], entryID: UUID) throws -> [String] {
        guard let directory = screenshotsDirectoryURL else {
            return []
        }

        var persisted: [String] = []
        do {
            for (index, data) in screenshots.enumerated() {
                let fileName = "\(entryID.uuidString)-\(index + 1).png"
                try data.write(to: directory.appendingPathComponent(fileName), options: .atomic)
                persisted.append(fileName)
            }
            return persisted
        } catch {
            removeScreenshots(named: persisted)
            throw error
        }
    }

    private func removeScreenshots(named fileNames: [String]) {
        guard let directory = screenshotsDirectoryURL else {
            return
        }
        for fileName in fileNames {
            try? fileManager.removeItem(at: directory.appendingPathComponent(fileName))
        }
    }

    private func load() {
        guard let url = entriesFileURL, let data = try? Data(contentsOf: url) else {
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        entries = (try? decoder.decode([MBIssueEntry].self, from: data)) ?? []
    }

    private func persist() {
        guard let url = entriesFileURL else {
            return
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(entries) else {
            return
        }
        try? data.write(to: url, options: .atomic)
    }

    #if DEBUG
        static func preview(entries: [MBIssueEntry] = []) -> MBIssueStore {
            let store = MBIssueStore(rootURL: nil)
            store.entries = entries
            return store
        }
    #endif
}
