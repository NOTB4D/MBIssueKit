#if canImport(UIKit)
    import SwiftUI

    struct MBIssueListView: View {
        let destinationName: String
        let onClose: () -> Void
        let onNewIssue: () -> Void
        let onRetry: (UUID) -> Void
        let onSubmitSelected: ([UUID]) -> Void
        let onOpen: (URL) -> Void
        let onExport: ([MBIssueEntry]) -> Void

        @EnvironmentObject private var store: MBIssueStore
        @EnvironmentObject private var reporterConnection: MBIssueReporterConnectionController
        @State private var deleteTarget: MBIssueEntry?
        @State private var detailEntry: MBIssueEntry?
        @State private var showDeleteAllConfirmation = false
        @State private var isSelecting = false
        @State private var batchSelection = MBIssueBatchSelection()

        var body: some View {
            VStack(spacing: 0) {
                header
                MBIssueReporterConnectionCard(controller: reporterConnection)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
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
                    if isSelecting {
                        batchActionArea
                    }
                }
            }
            .background(MBIssueTheme.background.ignoresSafeArea())
            .sheet(item: $detailEntry) { entry in
                MBIssueDetailView(
                    entry: entry,
                    screenshotURLs: store.screenshotURLs(for: entry),
                    onOpen: onOpen,
                    onExport: { onExport([entry]) }
                )
            }
            .alert(item: $deleteTarget) { entry in
                Alert(
                    title: Text("Delete this report?"),
                    message: Text("The local report and its screenshots will be removed. A remote task that already exists is not deleted."),
                    primaryButton: .destructive(Text("Delete")) { store.delete(entry) },
                    secondaryButton: .cancel()
                )
            }
            .alert("Delete all local reports?", isPresented: $showDeleteAllConfirmation) {
                Button("Delete all", role: .destructive) { store.deleteAll() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Existing remote tasks are not deleted.")
            }
            .onChange(of: store.entries) { entries in
                let eligibleIDs = MBIssueBatchSelection.eligibleIDs(in: entries)
                batchSelection.reconcile(eligibleIDs: eligibleIDs)
                if isSelecting, eligibleIDs.isEmpty {
                    isSelecting = false
                }
            }
            .task { await reporterConnection.refresh() }
        }

        private var header: some View {
            HStack(spacing: 12) {
                if isSelecting {
                    Button {
                        endSelection()
                    } label: {
                        Text("Cancel")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(MBIssueTheme.primaryText)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Select reports")
                            .font(.headline)
                            .foregroundColor(MBIssueTheme.primaryText)
                        Text("\(batchSelection.selectedIDs.count) of \(eligibleIDs.count) selected")
                            .font(.caption)
                            .foregroundColor(MBIssueTheme.secondaryText)
                    }

                    Spacer()

                    Button(allEligibleAreSelected ? "Clear" : "Select all") {
                        if allEligibleAreSelected {
                            batchSelection.clear()
                        } else {
                            batchSelection.selectAll(eligibleIDs: eligibleIDs)
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(MBIssueTheme.accent)
                    .accessibilityIdentifier("mbissue.select-all")
                } else {
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
                        Text(reporterConnection.state.provider?.destinationName ?? destinationName)
                            .font(.caption)
                            .foregroundColor(MBIssueTheme.secondaryText)
                    }

                    Spacer()

                    if !store.entries.isEmpty {
                        Button {
                            isSelecting = true
                        } label: {
                            Image(systemName: "checkmark.circle")
                                .frame(width: 36, height: 36)
                        }
                        .foregroundColor(MBIssueTheme.secondaryText)
                        .disabled(eligibleIDs.isEmpty)
                        .accessibilityLabel("Select reports to create in the issue tracker")
                        .accessibilityIdentifier("mbissue.select")

                        Menu {
                            Button {
                                onExport(store.entries)
                            } label: {
                                Label("Export all as ZIP", systemImage: "square.and.arrow.up")
                            }
                            Button(role: .destructive) {
                                showDeleteAllConfirmation = true
                            } label: {
                                Label("Delete all local reports", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .frame(width: 36, height: 36)
                        }
                        .foregroundColor(MBIssueTheme.secondaryText)
                        .accessibilityLabel("More report actions")
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
                statusColor(entry.submissionStatus)
                    .frame(width: 3)

                if isSelecting {
                    selectionControl(entry)
                }

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
                        Text(entry.severity.title)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(severityColor(entry.severity))
                        if !entry.screenshotFileNames.isEmpty {
                            Label("\(entry.screenshotFileNames.count)", systemImage: "photo")
                        }
                        if let key = entry.submission?.issueKey {
                            Text(key)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(MBIssueTheme.accent)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(MBIssueTheme.tertiaryText)

                    if let message = entry.submissionMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(entry.submissionStatus == .failed ? MBIssueTheme.failure : MBIssueTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 10) {
                        if isSelecting {
                            Text(selectionHint(for: entry))
                                .font(.caption.weight(.semibold))
                                .foregroundColor(isEligible(entry) ? MBIssueTheme.accent : MBIssueTheme.tertiaryText)
                        } else {
                            smallAction("Details", systemImage: "doc.text.magnifyingglass", color: MBIssueTheme.primaryText) {
                                detailEntry = entry
                            }
                            if isEligible(entry) {
                                smallAction("Retry", systemImage: "arrow.clockwise", color: MBIssueTheme.accent) {
                                    onRetry(entry.id)
                                }
                            }
                            if let submission = entry.submission {
                                smallAction("Open \(submission.providerDisplayName)", systemImage: "arrow.up.right", color: MBIssueTheme.success) {
                                    let url = submission.issueURL
                                    onOpen(url)
                                }
                            }
                        }
                        Spacer()
                        if !isSelecting {
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

        private func selectionControl(_ entry: MBIssueEntry) -> some View {
            let eligible = isEligible(entry)
            let selected = batchSelection.selectedIDs.contains(entry.id)
            return Button {
                batchSelection.toggle(entry.id, eligibleIDs: eligibleIDs)
            } label: {
                Image(systemName: selectionIcon(for: entry, selected: selected))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(selectionColor(for: entry, selected: selected))
                    .frame(width: 48, height: 54)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!eligible)
            .accessibilityLabel(selected ? "Deselect \(entry.title)" : "Select \(entry.title)")
            .accessibilityIdentifier("mbissue.select.\(entry.id.uuidString)")
        }

        private var batchActionArea: some View {
            VStack(spacing: 7) {
                Button(action: submitSelection) {
                    HStack(spacing: 9) {
                        Image(systemName: "arrow.up.right.square.fill")
                        Text("Create Selected")
                        Text("\(batchSelection.selectedIDs.count)")
                            .font(.caption.bold().monospacedDigit())
                            .foregroundColor(.black)
                            .frame(minWidth: 24, minHeight: 24)
                            .background(Color.black.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .font(.body.weight(.bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(isBatchSubmissionEnabled ? MBIssueTheme.accent : MBIssueTheme.elevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!isBatchSubmissionEnabled)
                .accessibilityIdentifier("mbissue.submit-selected")

                Text(batchSubmissionHint)
                    .font(.caption2)
                    .foregroundColor(MBIssueTheme.tertiaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(MBIssueTheme.surface)
            .overlay(alignment: .top) { MBIssueTheme.border.frame(height: 1) }
        }

        private func statusBadge(_ entry: MBIssueEntry) -> some View {
            HStack(spacing: 5) {
                if entry.submissionStatus == .submitting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.65)
                } else {
                    Circle()
                        .fill(statusColor(entry.submissionStatus))
                        .frame(width: 6, height: 6)
                }
                Text(statusTitle(entry.submissionStatus).uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.6)
            }
            .foregroundColor(statusColor(entry.submissionStatus))
            .padding(.horizontal, 9)
            .frame(height: 26)
            .background(statusColor(entry.submissionStatus).opacity(0.12))
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
                Text("Create a focused task with visible technical context and without application logs.")
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
            store.entries.filter { $0.submissionStatus == .notSubmitted || $0.submissionStatus == .submitting }.count
        }

        private var submittedCount: Int {
            store.entries.filter { $0.submissionStatus == .submitted }.count
        }

        private var failedCount: Int {
            store.entries.filter { $0.submissionStatus == .failed }.count
        }

        private var eligibleIDs: Set<UUID> {
            MBIssueBatchSelection.eligibleIDs(in: store.entries)
        }

        private var allEligibleAreSelected: Bool {
            !eligibleIDs.isEmpty && batchSelection.selectedIDs == eligibleIDs
        }

        private func isEligible(_ entry: MBIssueEntry) -> Bool {
            eligibleIDs.contains(entry.id)
        }

        private func selectionIcon(for entry: MBIssueEntry, selected: Bool) -> String {
            if selected {
                return "checkmark.circle.fill"
            }
            switch entry.submissionStatus {
            case .submitted: return "checkmark.seal.fill"
            case .submitting: return "hourglass.circle.fill"
            case .notSubmitted, .failed: return "circle"
            }
        }

        private func selectionColor(for entry: MBIssueEntry, selected: Bool) -> Color {
            if selected {
                return MBIssueTheme.accent
            }
            return entry.submissionStatus == .submitted ? MBIssueTheme.success : MBIssueTheme.tertiaryText
        }

        private func selectionHint(for entry: MBIssueEntry) -> String {
            switch entry.submissionStatus {
            case .notSubmitted, .failed: "Available for submission"
            case .submitting: "Submission in progress"
            case .submitted: "Already created in the issue tracker"
            }
        }

        private func submitSelection() {
            let ids = store.entries.compactMap { entry in
                batchSelection.selectedIDs.contains(entry.id) ? entry.id : nil
            }
            guard !ids.isEmpty else { return }
            onSubmitSelected(ids)
            endSelection()
        }

        private var isBatchSubmissionEnabled: Bool {
            !batchSelection.isEmpty && reporterConnection.state.canSubmit
        }

        private var batchSubmissionHint: String {
            if reporterConnection.state.canSubmit {
                return "Each selected report creates a separate task. Failed reports stay retryable."
            }
            return "Connect a verified reporter account before submitting the selected reports."
        }

        private func endSelection() {
            batchSelection.clear()
            isSelecting = false
        }

        private func statusColor(_ status: MBIssueSubmissionStatus) -> Color {
            switch status {
            case .notSubmitted, .submitting: MBIssueTheme.pending
            case .submitted: MBIssueTheme.success
            case .failed: MBIssueTheme.failure
            }
        }

        private func statusTitle(_ status: MBIssueSubmissionStatus) -> String {
            switch status {
            case .notSubmitted: "Pending"
            case .submitting: "Sending"
            case .submitted: "Created"
            case .failed: "Failed"
            }
        }

        private func severityColor(_ severity: MBIssueSeverity) -> Color {
            switch severity {
            case .blocker: MBIssueTheme.failure
            case .major: MBIssueTheme.accent
            case .minor: MBIssueTheme.pending
            case .cosmetic: MBIssueTheme.success
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
                destinationName: "MOB",
                onClose: {},
                onNewIssue: {},
                onRetry: { _ in },
                onSubmitSelected: { _ in },
                onOpen: { _ in },
                onExport: { _ in }
            )
            .environmentObject(MBIssueStore.preview(entries: [
                MBIssueEntry(
                    id: UUID(),
                    createdAt: Date().addingTimeInterval(-240),
                    title: "Checkout button is unresponsive",
                    description: "Tapping Continue does not move to the payment step.",
                    screenshotFileNames: ["capture.png"],
                    submissionStatus: .submitted,
                    submission: .init(
                        providerID: "issue-tracker",
                        providerDisplayName: "Issue tracker",
                        issueID: "10042",
                        issueKey: "MOB-42",
                        issueURL: URL(string: "https://example.atlassian.net/browse/MOB-42")!,
                        createdAt: Date()
                    ),
                    submissionMessage: "MOB-42 created in Issue tracker."
                ),
                MBIssueEntry(
                    id: UUID(),
                    createdAt: Date().addingTimeInterval(-900),
                    title: "Basket total is stale",
                    description: "Removing a product does not refresh the total.",
                    screenshotFileNames: [],
                    submissionStatus: .failed,
                    submissionMessage: "Network error: The connection was lost."
                ),
            ]))
            .environmentObject(MBIssueReporterConnectionController(
                managedProviderDisplayName: "Preview tracker"
            ))
            .preferredColorScheme(.dark)
        }

        #Preview("Empty issue list") {
            MBIssueListView(
                destinationName: "MOB",
                onClose: {},
                onNewIssue: {},
                onRetry: { _ in },
                onSubmitSelected: { _ in },
                onOpen: { _ in },
                onExport: { _ in }
            )
            .environmentObject(MBIssueStore.preview())
            .environmentObject(MBIssueReporterConnectionController(
                managedProviderDisplayName: "Preview tracker"
            ))
            .preferredColorScheme(.dark)
        }
    #endif
#endif
