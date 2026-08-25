#if canImport(UIKit)
    import SwiftUI

    struct MBIssueTechnicalContextCard: View {
        let context: MBIssueTechnicalContext
        @State private var isExpanded: Bool

        init(context: MBIssueTechnicalContext, initiallyExpanded: Bool = false) {
            self.context = context
            _isExpanded = State(initialValue: initiallyExpanded)
        }

        var body: some View {
            MBIssueCard {
                VStack(alignment: .leading, spacing: 13) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "curlybraces")
                                .font(.body.weight(.semibold))
                                .foregroundColor(MBIssueTheme.accent)
                                .frame(width: 38, height: 38)
                                .background(MBIssueTheme.accent.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Technical context captured")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(MBIssueTheme.primaryText)
                                Text("\(context.appName) · v\(context.appVersion) (\(context.buildNumber)) · \(context.osVersion)")
                                    .font(.caption)
                                    .foregroundColor(MBIssueTheme.secondaryText)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 4)
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.bold))
                                .foregroundColor(MBIssueTheme.tertiaryText)
                                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("mbissue.technical-context")

                    if isExpanded {
                        Divider().overlay(MBIssueTheme.border)
                        VStack(spacing: 10) {
                            detailRow("Screen", context.screenName)
                            detailRow("Controller", context.viewControllerName)
                            detailRow("Environment", context.environment)
                            detailRow("Device", "\(context.deviceModel) · \(context.deviceIdentifier)")
                            detailRow("Architecture", context.architecture)
                            detailRow("Appearance", context.isDarkMode ? "Dark" : "Light")
                            detailRow("Locale", context.locale)
                            detailRow("Screen size", context.screenSize)
                            detailRow("Bundle", context.bundleIdentifier)
                            if !context.navigationStack.isEmpty {
                                detailRow("Navigation", context.navigationStack.joined(separator: " → "))
                            }
                            ForEach(context.additional.keys.sorted(), id: \.self) { key in
                                if let value = context.additional[key] {
                                    detailRow(key, value)
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }

        private func detailRow(_ title: String, _ value: String) -> some View {
            HStack(alignment: .top, spacing: 12) {
                Text(title)
                    .foregroundColor(MBIssueTheme.secondaryText)
                    .frame(width: 88, alignment: .leading)
                Text(value)
                    .foregroundColor(MBIssueTheme.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .font(.caption)
        }
    }
#endif
