#if canImport(UIKit)
import SwiftUI
import UIKit

@MainActor
final class MBIssueOverlayController {
    static let shared = MBIssueOverlayController()

    private(set) var isInstalled = false

    private let store = MBIssueStore.shared
    private var configuration: MBIssueKitConfiguration?
    private var jiraClient: MBIssueJiraClient?
    private var overlayWindow: MBIssueOverlayWindow?
    private weak var referenceWindow: UIWindow?
    private var submissionTasks: [UUID: Task<Void, Never>] = [:]

    private init() {}

    func configure(_ configuration: MBIssueKitConfiguration) {
        self.configuration = configuration
        jiraClient = MBIssueJiraClient(configuration: configuration.jira)
    }

    func install(referenceWindow: UIWindow?) {
        guard overlayWindow == nil else { return }
        guard configuration != nil else {
            assertionFailure("Call MBIssueKit.configure(_:) before install().")
            return
        }

        let scene = referenceWindow?.windowScene ?? activeWindowScene()
        self.referenceWindow = referenceWindow
            ?? scene?.windows.first(where: \.isKeyWindow)
            ?? scene?.windows.first
        let window: MBIssueOverlayWindow
        if let scene {
            window = MBIssueOverlayWindow(windowScene: scene)
        } else {
            window = MBIssueOverlayWindow(frame: UIScreen.main.bounds)
        }

        let root = MBIssueOverlayRootViewController()
        let bar = MBIssueFloatingBar(
            onReport: { [weak self] in self?.presentComposer() },
            onOpenList: { [weak self] in self?.presentList() },
            onFrameChange: { [weak window] frame in window?.interactiveFrame = frame }
        )
        let hosting = UIHostingController(rootView: bar.environmentObject(store))
        root.embed(hosting)

        window.rootViewController = root
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear
        window.isHidden = false
        overlayWindow = window
        isInstalled = true
    }

    func remove() {
        submissionTasks.values.forEach { $0.cancel() }
        submissionTasks.removeAll()
        overlayWindow?.rootViewController?.dismiss(animated: false)
        overlayWindow?.isHidden = true
        overlayWindow?.rootViewController = nil
        overlayWindow = nil
        referenceWindow?.makeKey()
        referenceWindow = nil
        isInstalled = false
    }

    private func presentComposer() {
        guard let root = overlayWindow?.rootViewController,
              root.presentedViewController == nil,
              let projectKey = configuration?.jira.projectKey else {
            return
        }
        let capturedImage = MBIssueCapture.screen(excluding: overlayWindow)
        let view = MBIssueComposerView(
            capturedImage: capturedImage,
            projectKey: projectKey,
            onCancel: { [weak self] in self?.dismissPresented() },
            onCreate: { [weak self] draft, images in
                guard let self else { return }
                let entry = try store.add(
                    draft: draft,
                    screenshotData: images.compactMap { $0.pngData() }
                )
                dismissPresented()
                submit(id: entry.id)
            }
        )
        present(view.environmentObject(store), from: root)
    }

    private func presentList() {
        guard let root = overlayWindow?.rootViewController,
              root.presentedViewController == nil,
              let projectKey = configuration?.jira.projectKey else {
            return
        }
        let view = MBIssueListView(
            projectKey: projectKey,
            onClose: { [weak self] in self?.dismissPresented() },
            onNewIssue: { [weak self] in
                self?.dismissPresented {
                    self?.presentComposer()
                }
            },
            onRetry: { [weak self] id in self?.submit(id: id) },
            onOpen: { UIApplication.shared.open($0) }
        )
        present(view.environmentObject(store), from: root)
    }

    private func present<Content: View>(_ view: Content, from root: UIViewController) {
        let hosting = UIHostingController(rootView: view)
        hosting.modalPresentationStyle = .fullScreen
        hosting.isModalInPresentation = true
        hosting.view.backgroundColor = .clear
        overlayWindow?.makeKey()
        root.present(hosting, animated: true)
    }

    private func dismissPresented(completion: (() -> Void)? = nil) {
        overlayWindow?.rootViewController?.dismiss(animated: true) { [weak self] in
            self?.referenceWindow?.makeKey()
            completion?()
        }
    }

    private func submit(id: UUID) {
        guard submissionTasks[id] == nil, let jiraClient else { return }
        let task = Task { [weak self] in
            guard let self else { return }
            defer { submissionTasks[id] = nil }
            let submitter = MBIssueJiraSubmitter(store: store, client: jiraClient)
            await submitter.submit(ids: [id])
        }
        submissionTasks[id] = task
    }

    private func activeWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }
}
#endif
