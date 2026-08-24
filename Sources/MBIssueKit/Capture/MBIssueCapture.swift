#if canImport(UIKit)
import UIKit

@MainActor
enum MBIssueCapture {
    static func screen(excluding excludedWindow: UIWindow?) -> UIImage? {
        let windows = visibleWindows(excluding: excludedWindow)
        guard let referenceWindow = windows.first else {
            return nil
        }

        let bounds = referenceWindow.screen.bounds
        let format = UIGraphicsImageRendererFormat()
        format.scale = referenceWindow.screen.scale
        format.opaque = true
        let background = UIColor.systemBackground.resolvedColor(with: referenceWindow.traitCollection)

        return UIGraphicsImageRenderer(bounds: bounds, format: format).image { context in
            background.setFill()
            context.fill(bounds)
            for window in windows {
                let frame = window.frame.isEmpty ? bounds : window.frame
                if !window.drawHierarchy(in: frame, afterScreenUpdates: true) {
                    context.cgContext.saveGState()
                    context.cgContext.translateBy(x: frame.minX, y: frame.minY)
                    window.layer.render(in: context.cgContext)
                    context.cgContext.restoreGState()
                }
            }
        }
    }

    private static func visibleWindows(excluding excludedWindow: UIWindow?) -> [UIWindow] {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        return (scene?.windows ?? [])
            .filter { $0 !== excludedWindow && !$0.isHidden && $0.alpha > 0.01 }
            .sorted { $0.windowLevel.rawValue < $1.windowLevel.rawValue }
    }
}
#endif
