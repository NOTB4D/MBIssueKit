#if canImport(UIKit)
    import SwiftUI
    import UIKit

    struct MBIssueComposerView: View {
        let capturedImage: UIImage?
        let destinationName: String
        let technicalContext: MBIssueTechnicalContext
        let onCancel: () -> Void
        let onSaveDraft: (MBIssueDraft, [UIImage]) throws -> Void
        let onCreate: (MBIssueDraft, [UIImage]) throws -> Void

        @EnvironmentObject private var reporterConnection: MBIssueReporterConnectionController
        @State private var title = ""
        @State private var issueDescription = ""
        @State private var severity = MBIssueSeverity.major
        @State private var screenshots: [Screenshot]
        @State private var annotationTarget: Screenshot?
        @State private var isPhotoPickerPresented = false
        @State private var errorMessage: String?
        @FocusState private var focusedField: Field?

        init(
            capturedImage: UIImage?,
            destinationName: String,
            technicalContext: MBIssueTechnicalContext,
            onCancel: @escaping () -> Void,
            onSaveDraft: @escaping (MBIssueDraft, [UIImage]) throws -> Void,
            onCreate: @escaping (MBIssueDraft, [UIImage]) throws -> Void
        ) {
            self.capturedImage = capturedImage
            self.destinationName = destinationName
            self.technicalContext = technicalContext
            self.onCancel = onCancel
            self.onSaveDraft = onSaveDraft
            self.onCreate = onCreate
            _screenshots = State(initialValue: capturedImage.map { [Screenshot(image: $0)] } ?? [])
        }

        var body: some View {
            VStack(spacing: 0) {
                header
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        hero
                        MBIssueReporterConnectionCard(controller: reporterConnection)
                        titleCard
                        descriptionCard
                        severityCard
                        MBIssueTechnicalContextCard(context: technicalContext)
                        evidenceCard
                        privacyNote
                    }
                    .padding(16)
                }
                .background(MBIssueTheme.background)
                .onTapGesture { focusedField = nil }
                actionArea
            }
            .background(MBIssueTheme.background.ignoresSafeArea())
            .sheet(isPresented: $isPhotoPickerPresented) {
                MBIssuePhotoPicker { images in
                    screenshots.append(contentsOf: images.map { Screenshot(image: $0) })
                }
            }
            .fullScreenCover(item: $annotationTarget) { target in
                MBIssueImageEditor(
                    image: target.image,
                    onCancel: { annotationTarget = nil },
                    onSave: { image in
                        replaceScreenshot(target.id, with: image)
                        annotationTarget = nil
                    }
                )
            }
            .alert("Issue could not be saved", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
            .onAppear { focusedField = .title }
            .task { await reporterConnection.refresh() }
        }

        private var header: some View {
            HStack {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(MBIssueTheme.elevatedSurface)
                        .clipShape(Circle())
                }
                .foregroundColor(MBIssueTheme.primaryText)
                .accessibilityLabel("Close")

                Spacer()

                Text("New issue")
                    .font(.headline)
                    .foregroundColor(MBIssueTheme.primaryText)

                Spacer()
                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, 16)
            .frame(height: 58)
            .background(MBIssueTheme.surface)
            .overlay(alignment: .bottom) { MBIssueTheme.border.frame(height: 1) }
        }

        private var hero: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(providerDisplayName.uppercased()) · \(providerDestinationName)")
                    .font(.caption.weight(.bold))
                    .tracking(1.1)
                    .foregroundColor(MBIssueTheme.accent)

                Text("Report what happened")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundColor(MBIssueTheme.primaryText)

                Text("Give the team a clear title and enough detail to reproduce the issue.")
                    .font(.subheadline)
                    .foregroundColor(MBIssueTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
        }

        private var titleCard: some View {
            MBIssueCard {
                VStack(alignment: .leading, spacing: 10) {
                    fieldHeader(title: "Title", count: title.count, limit: MBIssueDraft.maximumTitleLength)

                    TextField("Short, specific summary", text: $title)
                        .font(.body.weight(.medium))
                        .foregroundColor(MBIssueTheme.primaryText)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .title)
                        .onSubmit { focusedField = .description }
                        .accessibilityIdentifier("mbissue.title")
                }
            }
        }

        private var descriptionCard: some View {
            MBIssueCard {
                VStack(alignment: .leading, spacing: 10) {
                    fieldHeader(
                        title: "Description",
                        count: issueDescription.count,
                        limit: MBIssueDraft.maximumDescriptionLength
                    )

                    ZStack(alignment: .topLeading) {
                        if issueDescription.isEmpty {
                            Text("What did you do, what happened, and what did you expect?")
                                .font(.body)
                                .foregroundColor(MBIssueTheme.tertiaryText)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $issueDescription)
                            .font(.body)
                            .foregroundColor(MBIssueTheme.primaryText)
                            .focused($focusedField, equals: .description)
                            .frame(minHeight: 150)
                            .background(Color.clear)
                            .accessibilityIdentifier("mbissue.description")
                    }
                }
            }
        }

        private var severityCard: some View {
            MBIssueCard {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Severity")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(MBIssueTheme.primaryText)
                        Text("Choose the impact on the user or business flow.")
                            .font(.caption)
                            .foregroundColor(MBIssueTheme.secondaryText)
                    }

                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                        spacing: 8
                    ) {
                        ForEach(MBIssueSeverity.allCases) { item in
                            severityButton(item)
                        }
                    }
                }
            }
        }

        private func severityButton(_ item: MBIssueSeverity) -> some View {
            let isSelected = severity == item
            let color = severityColor(item)
            return Button {
                severity = item
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: severityIcon(item))
                        .font(.caption.weight(.bold))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.caption.weight(.bold))
                        Text(severitySubtitle(item))
                            .font(.system(size: 10))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                    }
                }
                .foregroundColor(isSelected ? color : MBIssueTheme.secondaryText)
                .padding(.horizontal, 11)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .background(isSelected ? color.opacity(0.12) : MBIssueTheme.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isSelected ? color.opacity(0.75) : MBIssueTheme.border, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("mbissue.severity.\(item.rawValue)")
        }

        private var evidenceCard: some View {
            MBIssueCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Screenshots")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(MBIssueTheme.primaryText)
                            Text("Optional issue-tracker attachments")
                                .font(.caption)
                                .foregroundColor(MBIssueTheme.secondaryText)
                        }
                        Spacer()
                        Button {
                            isPhotoPickerPresented = true
                        } label: {
                            Label("Add", systemImage: "plus")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundColor(MBIssueTheme.accent)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 10) {
                            ForEach(screenshots) { screenshot in
                                screenshotTile(screenshot)
                            }
                            addScreenshotTile
                        }
                        .padding(.vertical, 1)
                    }
                }
            }
        }

        private func screenshotTile(_ screenshot: Screenshot) -> some View {
            ZStack(alignment: .topTrailing) {
                Button {
                    annotationTarget = screenshot
                } label: {
                    ZStack(alignment: .bottomLeading) {
                        Image(uiImage: screenshot.image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 126, height: 148)
                            .clipped()

                        Label("Annotate", systemImage: "pencil.tip")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 9)
                            .frame(height: 27)
                            .background(Color.black.opacity(0.72))
                            .clipShape(Capsule())
                            .padding(8)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    screenshots.removeAll { $0.id == screenshot.id }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(Color.black.opacity(0.72))
                        .clipShape(Circle())
                }
                .padding(7)
                .accessibilityLabel("Remove screenshot")
            }
        }

        private var addScreenshotTile: some View {
            Button {
                isPhotoPickerPresented = true
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.plus")
                        .font(.title3)
                    Text("Add image")
                        .font(.caption.weight(.semibold))
                }
                .foregroundColor(MBIssueTheme.accent)
                .frame(width: 94, height: 148)
                .background(MBIssueTheme.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(MBIssueTheme.border, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                }
            }
            .buttonStyle(.plain)
        }

        private var privacyNote: some View {
            Label {
                Text("Title, description, severity, the technical context shown above, and selected screenshots are sent to the configured issue tracker. Logs, network payloads, and state-management actions are never collected.")
            } icon: {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(MBIssueTheme.accent)
            }
            .font(.caption)
            .foregroundColor(MBIssueTheme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
        }

        private var actionArea: some View {
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Button(action: saveDraft) {
                        HStack(spacing: 7) {
                            Image(systemName: "tray.and.arrow.down.fill")
                            Text("Save Draft")
                        }
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(isDraftValid ? MBIssueTheme.primaryText : MBIssueTheme.tertiaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(MBIssueTheme.elevatedSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .stroke(MBIssueTheme.border, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!isDraftValid)
                    .accessibilityIdentifier("mbissue.save-draft")

                    Button(action: create) {
                        HStack(spacing: 7) {
                            Image(systemName: "arrow.up.right.square.fill")
                            Text("Create Task")
                        }
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(isSubmissionEnabled ? MBIssueTheme.accent : MBIssueTheme.elevatedSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!isSubmissionEnabled)
                    .accessibilityIdentifier("mbissue.create")
                }

                Text(submissionHint)
                    .font(.caption2)
                    .foregroundColor(MBIssueTheme.tertiaryText)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(MBIssueTheme.surface)
            .overlay(alignment: .top) { MBIssueTheme.border.frame(height: 1) }
        }

        private func fieldHeader(title: String, count: Int, limit: Int) -> some View {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(MBIssueTheme.primaryText)
                Spacer()
                Text("\(count) / \(limit)")
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(count > limit ? MBIssueTheme.failure : MBIssueTheme.tertiaryText)
            }
        }

        private var isDraftValid: Bool {
            (try? MBIssueDraft(
                title: title,
                description: issueDescription,
                severity: severity,
                technicalContext: technicalContext
            ).validated()) != nil
        }

        private var isSubmissionEnabled: Bool {
            isDraftValid && reporterConnection.state.canSubmit
        }

        private var providerDisplayName: String {
            reporterConnection.state.provider?.displayName ?? "Issue tracker"
        }

        private var providerDestinationName: String {
            reporterConnection.state.provider?.destinationName ?? destinationName
        }

        private var submissionHint: String {
            if reporterConnection.state.canSubmit {
                return "Save locally for a later batch, or create a separate task now."
            }
            return "Connect a verified reporter account above to create a task. Saving a local draft is still available."
        }

        private var errorBinding: Binding<Bool> {
            Binding(
                get: { errorMessage != nil },
                set: {
                    if !$0 {
                        errorMessage = nil
                    }
                }
            )
        }

        private func create() {
            perform(onCreate)
        }

        private func saveDraft() {
            perform(onSaveDraft)
        }

        private func perform(_ action: (MBIssueDraft, [UIImage]) throws -> Void) {
            do {
                let draft = try MBIssueDraft(
                    title: title,
                    description: issueDescription,
                    severity: severity,
                    technicalContext: technicalContext
                ).validated()
                try action(draft, screenshots.map(\.image))
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        private func replaceScreenshot(_ id: UUID, with image: UIImage) {
            guard let index = screenshots.firstIndex(where: { $0.id == id }) else {
                return
            }
            screenshots[index].image = image
        }

        private func severityColor(_ severity: MBIssueSeverity) -> Color {
            switch severity {
            case .blocker: MBIssueTheme.failure
            case .major: MBIssueTheme.accent
            case .minor: MBIssueTheme.pending
            case .cosmetic: MBIssueTheme.success
            }
        }

        private func severityIcon(_ severity: MBIssueSeverity) -> String {
            switch severity {
            case .blocker: "exclamationmark.octagon.fill"
            case .major: "exclamationmark.triangle.fill"
            case .minor: "arrow.down.circle.fill"
            case .cosmetic: "paintbrush.fill"
            }
        }

        private func severitySubtitle(_ severity: MBIssueSeverity) -> String {
            switch severity {
            case .blocker: "Flow blocked"
            case .major: "High impact"
            case .minor: "Limited impact"
            case .cosmetic: "Visual only"
            }
        }
    }

    private extension MBIssueComposerView {
        enum Field: Hashable {
            case title
            case description
        }

        struct Screenshot: Identifiable {
            let id: UUID
            var image: UIImage

            init(id: UUID = UUID(), image: UIImage) {
                self.id = id
                self.image = image
            }
        }
    }

    #if DEBUG
        #Preview("New issue") {
            MBIssueComposerView(
                capturedImage: nil,
                destinationName: "MOB",
                technicalContext: MBIssueTechnicalContext(
                    screenName: "Checkout",
                    viewControllerName: "CheckoutViewController",
                    navigationStack: ["HomeViewController", "CheckoutViewController"],
                    appName: "Commerce",
                    bundleIdentifier: "com.mobven.commerce",
                    appVersion: "100.0.1",
                    buildNumber: "8",
                    osVersion: "iOS 26.5",
                    deviceModel: "iPhone",
                    deviceIdentifier: "iPhone18,2",
                    architecture: "arm64",
                    environment: "development",
                    locale: "tr_TR",
                    isDarkMode: true,
                    screenSize: "402 × 874 pt @3x"
                ),
                onCancel: {},
                onSaveDraft: { _, _ in },
                onCreate: { _, _ in }
            )
            .preferredColorScheme(.dark)
        }
    #endif
#endif
