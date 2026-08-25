import Foundation

#if canImport(UIKit)
    import UIKit
#endif

/// Installs and controls the in-app issue reporter.
public enum MBIssueKit {
    /// Configures the package before its overlay is installed.
    ///
    /// Call this once during development-only app startup. Calling it again replaces
    /// the previous configuration and rebuilds the gateway client. Supply a custom URL
    /// session when the host needs a mock transport or additional networking policy.
    @MainActor
    public static func configure(
        _ configuration: MBIssueKitConfiguration,
        urlSession: URLSession = .shared
    ) {
        #if canImport(UIKit)
            MBIssueOverlayController.shared.configure(configuration, urlSession: urlSession)
        #endif
    }

    #if canImport(UIKit)
        /// Installs the floating issue reporter above the host application's windows.
        @MainActor
        public static func install(referenceWindow: UIWindow? = nil) {
            MBIssueOverlayController.shared.install(referenceWindow: referenceWindow)
        }

        /// Toggles only the floating reporter bar.
        ///
        /// Use this for shake gestures: a shake shows the bar when hidden and removes
        /// it when visible. The composer is opened explicitly from the bar.
        @MainActor
        public static func toggle(referenceWindow: UIWindow? = nil) {
            MBIssueOverlayController.shared.toggle(referenceWindow: referenceWindow)
        }

        /// Presents the issue composer, installing the overlay first when needed.
        ///
        /// Prefer `toggle(referenceWindow:)` for shake gestures.
        @MainActor
        public static func present(referenceWindow: UIWindow? = nil) {
            MBIssueOverlayController.shared.presentComposer(referenceWindow: referenceWindow)
        }

        /// Removes the floating issue reporter and dismisses its presented content.
        @MainActor
        public static func remove() {
            MBIssueOverlayController.shared.remove()
        }

        /// Indicates whether the floating issue reporter is installed.
        @MainActor
        public static var isInstalled: Bool {
            MBIssueOverlayController.shared.isInstalled
        }
    #endif
}
