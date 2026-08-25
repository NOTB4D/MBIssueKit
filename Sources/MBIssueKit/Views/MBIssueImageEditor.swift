#if canImport(UIKit)
    import SwiftUI
    import UIKit

    struct MBIssueImageEditor: View {
        let image: UIImage
        let onCancel: () -> Void
        let onSave: (UIImage) -> Void

        @State private var annotations: [MBIssueImageAnnotation] = []
        @State private var selectedTool = MBIssueAnnotationTool.pen
        @State private var selectedColor = MBIssueAnnotationColor.orange
        @State private var textPoint: CGPoint?
        @State private var textDraft = ""
        @State private var isTextPromptPresented = false

        var body: some View {
            VStack(spacing: 0) {
                header
                editor
                palette
            }
            .background(MBIssueTheme.background.ignoresSafeArea())
            .alert("Add annotation", isPresented: $isTextPromptPresented) {
                TextField("Text", text: $textDraft)
                Button("Cancel", role: .cancel) {
                    textDraft = ""
                    textPoint = nil
                }
                Button("Add") { addText() }
            } message: {
                Text("Enter the text that should appear on the screenshot.")
            }
        }

        private var header: some View {
            HStack(spacing: 12) {
                Button("Cancel", action: onCancel)
                    .foregroundColor(MBIssueTheme.secondaryText)

                Spacer()

                Text("Annotate")
                    .font(.headline)
                    .foregroundColor(MBIssueTheme.primaryText)

                Spacer()

                Button {
                    _ = annotations.popLast()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .frame(width: 32, height: 32)
                }
                .disabled(annotations.isEmpty)
                .accessibilityLabel("Undo annotation")

                Button("Done") {
                    onSave(MBIssueAnnotationRenderer.render(image: image, annotations: annotations))
                }
                .font(.subheadline.weight(.semibold))
            }
            .font(.subheadline)
            .foregroundColor(MBIssueTheme.accent)
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(MBIssueTheme.surface)
            .overlay(alignment: .bottom) { MBIssueTheme.border.frame(height: 1) }
        }

        private var editor: some View {
            GeometryReader { geometry in
                let size = fittedSize(image: image.size, available: geometry.size)
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                    MBIssueAnnotationCanvas(
                        annotations: annotations,
                        tool: selectedTool,
                        color: selectedColor,
                        onAnnotation: { annotations.append($0) },
                        onTextPoint: presentTextPrompt
                    )
                }
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(MBIssueTheme.border, lineWidth: 1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(16)
            }
        }

        private var palette: some View {
            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    ForEach(MBIssueAnnotationTool.allCases) { tool in
                        Button {
                            selectedTool = tool
                        } label: {
                            Image(systemName: tool.systemImage)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(selectedTool == tool ? .black : MBIssueTheme.primaryText)
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(selectedTool == tool ? MBIssueTheme.accent : MBIssueTheme.elevatedSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(tool.accessibilityName)
                        .accessibilityAddTraits(selectedTool == tool ? .isSelected : [])
                    }
                }

                HStack(spacing: 18) {
                    ForEach(MBIssueAnnotationColor.allCases) { color in
                        Button {
                            selectedColor = color
                        } label: {
                            Circle()
                                .fill(color.color)
                                .frame(width: 25, height: 25)
                                .overlay {
                                    Circle().stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                                }
                                .overlay {
                                    Circle().stroke(Color.black.opacity(0.25), lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(color.rawValue.capitalized)
                        .accessibilityAddTraits(selectedColor == color ? .isSelected : [])
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            .background(MBIssueTheme.surface)
            .overlay(alignment: .top) { MBIssueTheme.border.frame(height: 1) }
        }

        private func fittedSize(image: CGSize, available: CGSize) -> CGSize {
            let available = CGSize(
                width: max(available.width - 32, 1),
                height: max(available.height - 32, 1)
            )
            let scale = min(available.width / image.width, available.height / image.height)
            return CGSize(width: image.width * scale, height: image.height * scale)
        }

        private func presentTextPrompt(at point: CGPoint) {
            textPoint = point
            textDraft = ""
            isTextPromptPresented = true
        }

        private func addText() {
            let value = textDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            if let textPoint, !value.isEmpty {
                annotations.append(.init(content: .text(value, point: textPoint), color: selectedColor))
            }
            textDraft = ""
            textPoint = nil
        }
    }
#endif
