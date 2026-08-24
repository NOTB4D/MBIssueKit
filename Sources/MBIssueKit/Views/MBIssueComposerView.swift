#if canImport(UIKit)
import SwiftUI
import UIKit

struct MBIssueComposerView: View {
    let capturedImage: UIImage?
    let projectKey: String
    let onCancel: () -> Void
    let onCreate: (MBIssueDraft, [UIImage]) throws -> Void

    @State private var title = ""
    @State private var issueDescription = ""
    @State private var screenshots: [Screenshot]
    @State private var annotationTarget: Screenshot?
    @State private var isPhotoPickerPresented = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    init(
        capturedImage: UIImage?,
        projectKey: String,
        onCancel: @escaping () -> Void,
        onCreate: @escaping (MBIssueDraft, [UIImage]) throws -> Void
    ) {
        self.capturedImage = capturedImage
        self.projectKey = projectKey
        self.onCancel = onCancel
        self.onCreate = onCreate
        _screenshots = State(initialValue: capturedImage.map { [Screenshot(image: $0)] } ?? [])
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    hero
                    titleCard
                    descriptionCard
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
            Text("JIRA TASK · \(projectKey)")
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

    private var evidenceCard: some View {
        MBIssueCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Screenshots")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(MBIssueTheme.primaryText)
                        Text("Optional Jira attachments")
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
            Text("Only your title, description, and selected screenshots are sent to Jira. No logs, navigation state, architecture details, or device context are collected.")
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
            Button(action: create) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.right.square.fill")
                    Text("Create Jira Task")
                }
                .font(.body.weight(.bold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(isCreateEnabled ? MBIssueTheme.accent : MBIssueTheme.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!isCreateEnabled)
            .accessibilityIdentifier("mbissue.create")

            Text("The report is saved locally first, then submitted to Jira.")
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

    private var isCreateEnabled: Bool {
        (try? MBIssueDraft(title: title, description: issueDescription).validated()) != nil
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func create() {
        do {
            let draft = try MBIssueDraft(title: title, description: issueDescription).validated()
            try onCreate(draft, screenshots.map(\.image))
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
#Preview("New Jira task") {
    MBIssueComposerView(
        capturedImage: nil,
        projectKey: "MOB",
        onCancel: {},
        onCreate: { _, _ in }
    )
    .preferredColorScheme(.dark)
}
#endif
#endif
