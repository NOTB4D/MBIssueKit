import Foundation

#if canImport(UIKit)
    import UIKit
#endif

/// Starts the direct provider and securely bootstraps its runtime credentials.
///
/// Await this once at application startup before installing the overlay.
@MainActor
public func start(_ configuration: MBIssueKitConfiguration) async throws {
    try await configuration.provider.prepare()
    #if canImport(UIKit)
        MBIssueOverlayController.shared.configure(configuration)
    #endif
}

#if canImport(UIKit)
    /// Installs the floating issue reporter above the host application's windows.
    @MainActor
    public func install(referenceWindow: UIWindow? = nil) {
        MBIssueOverlayController.shared.install(referenceWindow: referenceWindow)
    }

    /// Toggles only the floating reporter bar.
    ///
    /// Use this for shake gestures: a shake shows the bar when hidden and removes
    /// it when visible. The composer is opened explicitly from the bar.
    @MainActor
    public func toggle(referenceWindow: UIWindow? = nil) {
        MBIssueOverlayController.shared.toggle(referenceWindow: referenceWindow)
    }

    /// Presents the issue composer, installing the overlay first when needed.
    ///
    /// Prefer ``toggle(referenceWindow:)`` for shake gestures.
    @MainActor
    public func present(referenceWindow: UIWindow? = nil) {
        MBIssueOverlayController.shared.presentComposer(referenceWindow: referenceWindow)
    }

    /// Removes the floating issue reporter and dismisses its presented content.
    @MainActor
    public func remove() {
        MBIssueOverlayController.shared.remove()
    }

    /// Indicates whether the floating issue reporter is installed.
    @MainActor
    public var isInstalled: Bool {
        MBIssueOverlayController.shared.isInstalled
    }

    /// Forwards a custom URL callback delivered directly to the host app.
    ///
    /// Call this before the host application's own deep-link router. A `true`
    /// result means an active reporter authorization consumed the URL.
    @discardableResult
    @MainActor
    public func handleOpenURL(_ url: URL) -> Bool {
        MBIssueOverlayController.shared.handleOpenURL(url)
    }
#endif
