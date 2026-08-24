import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// Installs and controls the in-app Jira issue reporter.
public enum MBIssueKit {
    /// Configures the package before its overlay is installed.
    ///
    /// Call this once during development-only app startup. Calling it again replaces
    /// the previous configuration and rebuilds the Jira client.
    @MainActor
    public static func configure(_ configuration: MBIssueKitConfiguration) {
        #if canImport(UIKit)
        MBIssueOverlayController.shared.configure(configuration)
        #endif
    }

    #if canImport(UIKit)
    /// Installs the floating issue reporter above the host application's windows.
    @MainActor
    public static func install(referenceWindow: UIWindow? = nil) {
        MBIssueOverlayController.shared.install(referenceWindow: referenceWindow)
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
