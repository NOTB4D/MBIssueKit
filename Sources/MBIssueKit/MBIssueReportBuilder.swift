import Foundation

enum MBIssueReportBuilder {
    static func markdown(for entries: [MBIssueEntry]) -> String {
        var lines = [
            "# MBIssueKit report",
            "",
            "Generated: \(dateString(Date()))",
            "Reports: \(entries.count)",
        ]

        for entry in entries {
            lines.append(contentsOf: markdownSection(for: entry))
        }

        return lines.joined(separator: "\n") + "\n"
    }

    static func makeSharePackage(
        entries: [MBIssueEntry],
        screenshotURLs: [UUID: [URL]],
        fileManager: FileManager = .default
    ) throws -> URL {
        let identifier = UUID().uuidString
        let workspace = fileManager.temporaryDirectory
            .appendingPathComponent("MBIssueKitExport-\(identifier)", isDirectory: true)
        let source = workspace.appendingPathComponent("MBIssueKit-report", isDirectory: true)
        let screenshots = source.appendingPathComponent("screenshots", isDirectory: true)
        try fileManager.createDirectory(at: screenshots, withIntermediateDirectories: true)

        try Data(markdown(for: entries).utf8).write(
            to: source.appendingPathComponent("report.md"),
            options: .atomic
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(entries).write(
            to: source.appendingPathComponent("metadata.json"),
            options: .atomic
        )

        for entry in entries {
            for url in screenshotURLs[entry.id] ?? [] where fileManager.fileExists(atPath: url.path) {
                let destination = screenshots.appendingPathComponent(
                    exportedScreenshotName(entryID: entry.id, originalName: url.lastPathComponent)
                )
                try fileManager.copyItem(at: url, to: destination)
            }
        }

        let destination = fileManager.temporaryDirectory
            .appendingPathComponent("MBIssueKit-report-\(identifier).zip")
        var coordinationError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(
            readingItemAt: source,
            options: .forUploading,
            error: &coordinationError
        ) { archiveURL in
            do {
                try fileManager.copyItem(at: archiveURL, to: destination)
            } catch {
                copyError = error
            }
        }

        if let coordinationError {
            throw coordinationError
        }
        if let copyError {
            throw copyError
        }
        return destination
    }

    private static func markdownSection(for entry: MBIssueEntry) -> [String] {
        var lines = [
            "",
            "---",
            "",
            "## \(entry.title)",
            "",
            "**ID:** `\(entry.id.uuidString)`  ",
            "**Created:** \(dateString(entry.createdAt))  ",
            "**Severity:** \(entry.severity.title)  ",
            "**Submission status:** \(entry.submissionStatus.rawValue)",
            "",
            "### Description",
            "",
            entry.description,
        ]

        if let context = entry.technicalContext {
            lines.append(contentsOf: ["", "### Technical context", ""])
            lines.append(contentsOf: context.markdownLines)
        }

        if !entry.screenshotFileNames.isEmpty {
            lines.append(contentsOf: ["", "### Screenshots", ""])
            lines.append(contentsOf: entry.screenshotFileNames.map { name in
                let exportedName = exportedScreenshotName(entryID: entry.id, originalName: name)
                return "- [\(name)](screenshots/\(exportedName))"
            })
        }

        if let submission = entry.submission {
            lines.append(contentsOf: [
                "",
                "### \(submission.providerDisplayName)",
                "",
                "- Key: \(submission.issueKey)",
                "- URL: \(submission.issueURL.absoluteString)",
            ])
        }
        return lines
    }

    private static func exportedScreenshotName(entryID: UUID, originalName: String) -> String {
        "\(entryID.uuidString)-\(originalName)"
    }

    private static func dateString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

private extension MBIssueTechnicalContext {
    var markdownLines: [String] {
        var lines = [
            "- Screen: \(screenName)",
            "- View controller: \(viewControllerName)",
            "- Navigation stack: \(navigationStack.isEmpty ? "—" : navigationStack.joined(separator: " → "))",
            "- App: \(appName) \(appVersion) (\(buildNumber))",
            "- Bundle: \(bundleIdentifier)",
            "- Environment: \(environment)",
            "- OS: \(osVersion)",
            "- Device: \(deviceModel) · \(deviceIdentifier) · \(architecture)",
            "- Appearance: \(isDarkMode ? "Dark" : "Light")",
            "- Locale: \(locale)",
            "- Screen size: \(screenSize)",
        ]
        lines.append(contentsOf: additional.keys.sorted().compactMap { key in
            additional[key].map { "- \(key): \($0)" }
        })
        return lines
    }
}
