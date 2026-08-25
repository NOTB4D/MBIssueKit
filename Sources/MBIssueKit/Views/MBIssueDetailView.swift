#if canImport(UIKit)
    import SwiftUI
    import UIKit

    struct MBIssueDetailView: View {
        let entry: MBIssueEntry
        let screenshotURLs: [URL]
        let onOpen: (URL) -> Void
        let onExport: () -> Void

        @Environment(\.dismiss) private var dismiss

        var body: some View {
            NavigationView {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        overviewCard
                        descriptionCard
                        if let context = entry.technicalContext {
                            MBIssueTechnicalContextCard(context: context, initiallyExpanded: true)
                        }
                        screenshotsCard
                        jiraCard
                    }
                    .padding(16)
                }
                .background(MBIssueTheme.background.ignoresSafeArea())
                .navigationTitle("Report details")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: onExport) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Export report ZIP")
                    }
                }
            }
            .navigationViewStyle(.stack)
        }

        private var overviewCard: some View {
            MBIssueCard {
                VStack(alignment: .leading, spacing: 13) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.title)
                                .font(.title3.weight(.bold))
                                .foregroundColor(MBIssueTheme.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(entry.createdAt.formatted(date: .abbreviated, time: .standard))
                                .font(.caption)
                                .foregroundColor(MBIssueTheme.secondaryText)
                        }
                        Spacer(minLength: 4)
                        severityBadge
                    }

                    Divider().overlay(MBIssueTheme.border)

                    HStack {
                        Label(statusTitle, systemImage: statusIcon)
                            .foregroundColor(statusColor)
                        Spacer()
                        Text(entry.id.uuidString.prefix(8))
                            .font(.caption.monospaced())
                            .foregroundColor(MBIssueTheme.tertiaryText)
                    }
                    .font(.caption.weight(.semibold))
                }
            }
        }

        private var descriptionCard: some View {
            MBIssueCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Description", systemImage: "text.alignleft")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(MBIssueTheme.primaryText)
                    Text(entry.description)
                        .font(.body)
                        .foregroundColor(MBIssueTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        @ViewBuilder
        private var screenshotsCard: some View {
            if !screenshotURLs.isEmpty {
                MBIssueCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Screenshots", systemImage: "photo.on.rectangle.angled")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(MBIssueTheme.primaryText)

                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 10) {
                                ForEach(screenshotURLs, id: \.self) { url in
                                    if let image = UIImage(contentsOfFile: url.path) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 190, height: 280)
                                            .clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        private var jiraCard: some View {
            MBIssueCard {
                VStack(alignment: .leading, spacing: 11) {
                    Label("Jira", systemImage: "arrow.up.right.square")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(MBIssueTheme.primaryText)

                    if let submission = entry.jiraSubmission {
                        detailRow("Issue", submission.issueKey)
                        detailRow("Created", submission.createdAt.formatted(date: .abbreviated, time: .shortened))
                        Button {
                            onOpen(submission.issueURL)
                        } label: {
                            Label("Open \(submission.issueKey)", systemImage: "arrow.up.right")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(MBIssueTheme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(entry.jiraMessage ?? "This report has not been created in Jira yet.")
                            .font(.subheadline)
                            .foregroundColor(MBIssueTheme.secondaryText)
                    }
                }
            }
        }

        private var severityBadge: some View {
            Text(entry.severity.title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.6)
                .foregroundColor(severityColor)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(severityColor.opacity(0.12))
                .clipShape(Capsule())
        }

        private func detailRow(_ title: String, _ value: String) -> some View {
            HStack(alignment: .top, spacing: 12) {
                Text(title)
                    .foregroundColor(MBIssueTheme.secondaryText)
                    .frame(width: 68, alignment: .leading)
                Text(value)
                    .foregroundColor(MBIssueTheme.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.caption)
        }

        private var severityColor: Color {
            switch entry.severity {
            case .blocker: MBIssueTheme.failure
            case .major: MBIssueTheme.accent
            case .minor: MBIssueTheme.pending
            case .cosmetic: MBIssueTheme.success
            }
        }

        private var statusColor: Color {
            switch entry.jiraStatus {
            case .notSubmitted, .submitting: MBIssueTheme.pending
            case .submitted: MBIssueTheme.success
            case .failed: MBIssueTheme.failure
            }
        }

        private var statusTitle: String {
            switch entry.jiraStatus {
            case .notSubmitted: "Pending submission"
            case .submitting: "Sending to Jira"
            case .submitted: "Created in Jira"
            case .failed: "Submission failed"
            }
        }

        private var statusIcon: String {
            switch entry.jiraStatus {
            case .notSubmitted: "clock"
            case .submitting: "arrow.triangle.2.circlepath"
            case .submitted: "checkmark.circle.fill"
            case .failed: "exclamationmark.circle.fill"
            }
        }
    }
#endif
