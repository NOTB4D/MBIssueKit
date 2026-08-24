#if canImport(UIKit)
import SwiftUI

struct MBIssueListView: View {
    let projectKey: String
    let onClose: () -> Void
    let onNewIssue: () -> Void
    let onRetry: (UUID) -> Void
    let onOpen: (URL) -> Void

    @EnvironmentObject private var store: MBIssueStore
    @State private var deleteTarget: MBIssueEntry?
    @State private var showDeleteAllConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            header
            if store.entries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        summary
                        ForEach(store.entries) { entry in
                            issueCard(entry)
                        }
                    }
                    .padding(16)
                }
                .background(MBIssueTheme.background)
            }
        }
        .background(MBIssueTheme.background.ignoresSafeArea())
        .alert(item: $deleteTarget) { entry in
            Alert(
                title: Text("Delete this report?"),
                message: Text("The local report and its screenshots will be removed. A Jira task that already exists is not deleted."),
                primaryButton: .destructive(Text("Delete")) { store.delete(entry) },
                secondaryButton: .cancel()
            )
        }
        .alert("Delete all local reports?", isPresented: $showDeleteAllConfirmation) {
            Button("Delete all", role: .destructive) { store.deleteAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Existing Jira tasks are not deleted.")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(MBIssueTheme.elevatedSurface)
                    .clipShape(Circle())
            }
            .foregroundColor(MBIssueTheme.primaryText)
            .accessibilityLabel("Close")

            VStack(alignment: .leading, spacing: 2) {
                Text("Issue reports")
                    .font(.headline)
                    .foregroundColor(MBIssueTheme.primaryText)
                Text("Jira project \(projectKey)")
                    .font(.caption)
                    .foregroundColor(MBIssueTheme.secondaryText)
            }

            Spacer()

            if !store.entries.isEmpty {
                Button {
                    showDeleteAllConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 36, height: 36)
                }
                .foregroundColor(MBIssueTheme.secondaryText)
                .accessibilityLabel("Delete all local reports")
            }

            Button(action: onNewIssue) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 36, height: 36)
                    .background(MBIssueTheme.accent)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Create a new issue")
        }
        .padding(.horizontal, 16)
        .frame(height: 64)
        .background(MBIssueTheme.surface)
        .overlay(alignment: .bottom) { MBIssueTheme.border.frame(height: 1) }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SUBMISSION OVERVIEW")
                .font(.caption2.weight(.bold))
                .tracking(1)
                .foregroundColor(MBIssueTheme.accent)

            HStack(spacing: 8) {
                metric(value: pendingCount, label: "Pending", color: MBIssueTheme.pending)
                metric(value: submittedCount, label: "Created", color: MBIssueTheme.success)
                metric(value: failedCount, label: "Failed", color: MBIssueTheme.failure)
            }
        }
    }

    private func metric(value: Int, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(value)")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(MBIssueTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(MBIssueTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MBIssueTheme.border, lineWidth: 1)
        }
    }

    private func issueCard(_ entry: MBIssueEntry) -> some View {
        HStack(spacing: 0) {
            statusColor(entry.jiraStatus)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(entry.title)
                            .font(.body.weight(.semibold))
                            .foregroundColor(MBIssueTheme.primaryText)
                            .lineLimit(2)
                        Text(entry.description)
                            .font(.subheadline)
                            .foregroundColor(MBIssueTheme.secondaryText)
                            .lineLimit(3)
                    }

                    Spacer(minLength: 4)
                    statusBadge(entry)
                }

                HStack(spacing: 12) {
                    Label(relativeDate(entry.createdAt), systemImage: "clock")
                    if !entry.screenshotFileNames.isEmpty {
                        Label("\(entry.screenshotFileNames.count)", systemImage: "photo")
                    }
                    if let key = entry.jiraSubmission?.issueKey {
                        Text(key)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(MBIssueTheme.accent)
                    }
                }
                .font(.caption)
                .foregroundColor(MBIssueTheme.tertiaryText)

                if let message = entry.jiraMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(entry.jiraStatus == .failed ? MBIssueTheme.failure : MBIssueTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    if entry.jiraStatus == .notSubmitted || entry.jiraStatus == .failed {
                        smallAction("Retry", systemImage: "arrow.clockwise", color: MBIssueTheme.accent) {
                            onRetry(entry.id)
                        }
                    }
                    if let url = entry.jiraSubmission?.issueURL {
                        smallAction("Open Jira", systemImage: "arrow.up.right", color: MBIssueTheme.success) {
                            onOpen(url)
                        }
                    }
                    Spacer()
                    Button {
                        deleteTarget = entry
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption.weight(.semibold))
                            .frame(width: 34, height: 30)
                    }
                    .foregroundColor(MBIssueTheme.tertiaryText)
                    .accessibilityLabel("Delete \(entry.title)")
                }
            }
            .padding(15)
        }
        .background(MBIssueTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: MBIssueTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MBIssueTheme.cardRadius, style: .continuous)
                .stroke(MBIssueTheme.border, lineWidth: 1)
        }
    }

    private func statusBadge(_ entry: MBIssueEntry) -> some View {
        HStack(spacing: 5) {
            if entry.jiraStatus == .submitting {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.65)
            } else {
                Circle()
                    .fill(statusColor(entry.jiraStatus))
                    .frame(width: 6, height: 6)
            }
            Text(statusTitle(entry.jiraStatus).uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.6)
        }
        .foregroundColor(statusColor(entry.jiraStatus))
        .padding(.horizontal, 9)
        .frame(height: 26)
        .background(statusColor(entry.jiraStatus).opacity(0.12))
        .clipShape(Capsule())
    }

    private func smallAction(
        _ title: String,
        systemImage: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundColor(color)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(color.opacity(0.1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.bubble")
                .font(.system(size: 38, weight: .light))
                .foregroundColor(MBIssueTheme.accent)
                .frame(width: 76, height: 76)
                .background(MBIssueTheme.surface)
                .clipShape(Circle())

            Text("No issue reports yet")
                .font(.title3.weight(.bold))
                .foregroundColor(MBIssueTheme.primaryText)
            Text("Create a focused Jira task without attaching application logs or technical context.")
                .font(.subheadline)
                .foregroundColor(MBIssueTheme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            Button(action: onNewIssue) {
                Label("Create issue", systemImage: "plus")
                    .font(.body.weight(.bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .frame(height: 46)
                    .background(MBIssueTheme.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MBIssueTheme.background)
        .padding(24)
    }

    private var pendingCount: Int {
        store.entries.filter { $0.jiraStatus == .notSubmitted || $0.jiraStatus == .submitting }.count
    }

    private var submittedCount: Int {
        store.entries.filter { $0.jiraStatus == .submitted }.count
    }

    private var failedCount: Int {
        store.entries.filter { $0.jiraStatus == .failed }.count
    }

    private func statusColor(_ status: MBIssueEntry.JiraStatus) -> Color {
        switch status {
        case .notSubmitted, .submitting: return MBIssueTheme.pending
        case .submitted: return MBIssueTheme.success
        case .failed: return MBIssueTheme.failure
        }
    }

    private func statusTitle(_ status: MBIssueEntry.JiraStatus) -> String {
        switch status {
        case .notSubmitted: return "Pending"
        case .submitting: return "Sending"
        case .submitted: return "Created"
        case .failed: return "Failed"
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#if DEBUG
#Preview("Issue list") {
    MBIssueListView(
        projectKey: "MOB",
        onClose: {},
        onNewIssue: {},
        onRetry: { _ in },
        onOpen: { _ in }
    )
    .environmentObject(MBIssueStore.preview(entries: [
        MBIssueEntry(
            id: UUID(),
            createdAt: Date().addingTimeInterval(-240),
            title: "Checkout button is unresponsive",
            description: "Tapping Continue does not move to the payment step.",
            screenshotFileNames: ["capture.png"],
            jiraStatus: .submitted,
            jiraSubmission: .init(
                issueID: "10042",
                issueKey: "MOB-42",
                issueURL: URL(string: "https://example.atlassian.net/browse/MOB-42")!,
                createdAt: Date()
            ),
            jiraMessage: "MOB-42 created in Jira."
        ),
        MBIssueEntry(
            id: UUID(),
            createdAt: Date().addingTimeInterval(-900),
            title: "Basket total is stale",
            description: "Removing a product does not refresh the total.",
            screenshotFileNames: [],
            jiraStatus: .failed,
            jiraMessage: "Network error: The connection was lost."
        )
    ]))
    .preferredColorScheme(.dark)
}

#Preview("Empty issue list") {
    MBIssueListView(
        projectKey: "MOB",
        onClose: {},
        onNewIssue: {},
        onRetry: { _ in },
        onOpen: { _ in }
    )
    .environmentObject(MBIssueStore.preview())
    .preferredColorScheme(.dark)
}
#endif
#endif
