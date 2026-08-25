#if canImport(UIKit)
    import UIKit

    @MainActor
    enum MBIssueCapture {
        static func screen(
            referenceWindow: UIWindow? = nil,
            excluding excludedWindow: UIWindow?
        ) -> UIImage? {
            guard let referenceWindow = captureWindow(
                preferred: referenceWindow,
                excluding: excludedWindow
            ), let snapshotView = referenceWindow.rootViewController?.view else {
                return nil
            }

            snapshotView.layoutIfNeeded()
            let bounds = snapshotView.bounds
            guard !bounds.isEmpty else { return nil }

            let format = UIGraphicsImageRendererFormat()
            format.scale = referenceWindow.screen.scale
            format.opaque = false

            return UIGraphicsImageRenderer(bounds: bounds, format: format).image { context in
                if !snapshotView.drawHierarchy(in: bounds, afterScreenUpdates: false) {
                    snapshotView.layer.render(in: context.cgContext)
                }
            }
        }

        static func technicalContext(
            referenceWindow: UIWindow? = nil,
            excluding excludedWindow: UIWindow?,
            environment: String,
            additional: [String: String]
        ) -> MBIssueTechnicalContext {
            let window = captureWindow(preferred: referenceWindow, excluding: excludedWindow)
            let visibleController = visibleViewController(from: window?.rootViewController)
            let controllerName = visibleController.map { String(describing: type(of: $0)) } ?? "Unknown"
            let screenName = nonEmpty(visibleController?.title) ?? controllerName
            let navigationStack = visibleController?.navigationController?.viewControllers.map {
                String(describing: type(of: $0))
            } ?? []
            let bundle = Bundle.main
            let info = bundle.infoDictionary
            let screen = window?.screen ?? UIScreen.main
            let size = screen.bounds.size

            return MBIssueTechnicalContext(
                screenName: screenName,
                viewControllerName: controllerName,
                navigationStack: navigationStack,
                appName: nonEmpty(info?["CFBundleDisplayName"] as? String)
                    ?? nonEmpty(info?["CFBundleName"] as? String)
                    ?? "Unknown",
                bundleIdentifier: bundle.bundleIdentifier ?? "Unknown",
                appVersion: nonEmpty(info?["CFBundleShortVersionString"] as? String) ?? "Unknown",
                buildNumber: nonEmpty(info?["CFBundleVersion"] as? String) ?? "Unknown",
                osVersion: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
                deviceModel: UIDevice.current.model,
                deviceIdentifier: ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"]
                    ?? machineIdentifier(),
                architecture: architecture,
                environment: environment,
                locale: Locale.current.identifier,
                isDarkMode: window?.traitCollection.userInterfaceStyle == .dark,
                screenSize: "\(Int(size.width)) × \(Int(size.height)) pt @\(scaleText(screen.scale))x",
                additional: additional
            )
        }

        private static func captureWindow(
            preferred: UIWindow?,
            excluding excludedWindow: UIWindow?
        ) -> UIWindow? {
            if let preferred,
               preferred !== excludedWindow,
               !preferred.isHidden,
               preferred.alpha > 0.01
            {
                return preferred
            }

            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
            let windows = (scene?.windows ?? [])
                .filter { $0 !== excludedWindow && !$0.isHidden && $0.alpha > 0.01 }
            return windows.first(where: \.isKeyWindow)
                ?? windows.min { $0.windowLevel.rawValue < $1.windowLevel.rawValue }
        }

        private static func visibleViewController(from controller: UIViewController?) -> UIViewController? {
            guard let controller else { return nil }
            if let presented = controller.presentedViewController {
                return visibleViewController(from: presented)
            }
            if let navigation = controller as? UINavigationController {
                return visibleViewController(from: navigation.visibleViewController ?? navigation)
            }
            if let tab = controller as? UITabBarController {
                return visibleViewController(from: tab.selectedViewController ?? tab)
            }
            for child in controller.children.reversed() where child.viewIfLoaded?.window != nil {
                return visibleViewController(from: child)
            }
            return controller
        }

        private static func nonEmpty(_ value: String?) -> String? {
            guard let value else { return nil }
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return normalized.isEmpty ? nil : normalized
        }

        private static func machineIdentifier() -> String {
            var systemInfo = utsname()
            uname(&systemInfo)
            return withUnsafePointer(to: &systemInfo.machine) { pointer in
                pointer.withMemoryRebound(to: CChar.self, capacity: 1) { value in
                    String(cString: value)
                }
            }
        }

        private static var architecture: String {
            #if arch(arm64)
                return "arm64"
            #elseif arch(x86_64)
                return "x86_64"
            #elseif arch(arm)
                return "arm"
            #else
                return "unknown"
            #endif
        }

        private static func scaleText(_ scale: CGFloat) -> String {
            scale.rounded() == scale ? String(Int(scale)) : String(format: "%.1f", scale)
        }
    }
#endif
