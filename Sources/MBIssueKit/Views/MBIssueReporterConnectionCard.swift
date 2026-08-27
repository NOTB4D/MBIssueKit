#if canImport(UIKit)
    import SwiftUI

    struct MBIssueReporterConnectionCard: View {
        @ObservedObject var controller: MBIssueReporterConnectionController

        var body: some View {
            MBIssueCard {
                HStack(spacing: 13) {
                    icon
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(MBIssueTheme.primaryText)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(messageColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    action
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("mbissue.reporter-connection")
        }

        private var icon: some View {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 42, height: 42)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }

        @ViewBuilder
        private var action: some View {
            switch controller.state {
            case .idle, .loading, .authorizing:
                ProgressView()
                    .progressViewStyle(.circular)
            case .disconnected, .failed:
                Button("Connect") {
                    Task { await controller.connect() }
                }
                .font(.caption.weight(.bold))
                .foregroundColor(.black)
                .padding(.horizontal, 13)
                .frame(height: 34)
                .background(MBIssueTheme.accent)
                .clipShape(Capsule())
                .accessibilityIdentifier("mbissue.reporter-connect")
            case .connected:
                Menu {
                    Button(role: .destructive) {
                        Task { await controller.disconnect() }
                    } label: {
                        Label("Disconnect account", systemImage: "person.crop.circle.badge.xmark")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .foregroundColor(MBIssueTheme.secondaryText)
                        .frame(width: 34, height: 34)
                        .background(MBIssueTheme.elevatedSurface)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Reporter account actions")
            }
        }

        private var title: String {
            switch controller.state {
            case .idle, .loading:
                "Checking reporter account"
            case let .disconnected(provider):
                "Connect \(provider.displayName)"
            case let .authorizing(provider):
                "Authorizing \(provider?.displayName ?? "issue tracker")"
            case let .connected(connection):
                connection.reporter?.displayName ?? "Verified reporter"
            case let .failed(provider, _):
                "\(provider?.displayName ?? "Reporter") connection"
            }
        }

        private var subtitle: String {
            switch controller.state {
            case .idle, .loading:
                "Verifying the device-only reporting session."
            case let .disconnected(provider):
                "Required before creating work in \(provider.destinationName)."
            case .authorizing:
                "Complete the secure sign-in in the browser."
            case let .connected(connection):
                "\(connection.provider.displayName) · \(connection.provider.destinationName)"
            case let .failed(_, message):
                message
            }
        }

        private var iconName: String {
            switch controller.state {
            case .connected:
                "person.crop.circle.badge.checkmark"
            case .failed:
                "exclamationmark.shield.fill"
            case .idle, .loading, .disconnected, .authorizing:
                "person.crop.circle.badge.questionmark"
            }
        }

        private var iconColor: Color {
            switch controller.state {
            case .connected:
                MBIssueTheme.success
            case .failed:
                MBIssueTheme.failure
            case .idle, .loading, .disconnected, .authorizing:
                MBIssueTheme.accent
            }
        }

        private var messageColor: Color {
            if case .failed = controller.state {
                return MBIssueTheme.failure
            }
            return MBIssueTheme.secondaryText
        }
    }
#endif
