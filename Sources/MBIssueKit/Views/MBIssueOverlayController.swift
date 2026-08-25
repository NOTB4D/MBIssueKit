#if canImport(UIKit)
    import SwiftUI
    import UIKit

    @MainActor
    final class MBIssueOverlayController {
        static let shared = MBIssueOverlayController()

        private(set) var isInstalled = false

        private let store = MBIssueStore.shared
        private var configuration: MBIssueKitConfiguration?
        private var gatewayClient: MBIssueGatewayClient?
        private var overlayWindow: MBIssueOverlayWindow?
        private weak var referenceWindow: UIWindow?
        private var submissionTasks: [UUID: Task<Void, Never>] = [:]

        private init() {}

        func configure(
            _ configuration: MBIssueKitConfiguration,
            urlSession: URLSession
        ) {
            self.configuration = configuration
            gatewayClient = MBIssueGatewayClient(
                configuration: configuration.gateway,
                session: urlSession
            )
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
            let window = if let scene {
                MBIssueOverlayWindow(windowScene: scene)
            } else {
                MBIssueOverlayWindow(frame: UIScreen.main.bounds)
            }

            let root = MBIssueOverlayRootViewController()
            let bar = MBIssueFloatingBar(
                onReport: { [weak self] in self?.presentComposerContent() },
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

        func toggle(referenceWindow: UIWindow?) {
            let plan = MBIssueTogglePlan(
                isConfigured: configuration != nil,
                isInstalled: isInstalled
            )
            switch plan.step {
            case .install:
                install(referenceWindow: referenceWindow)
            case .remove:
                remove()
            case nil:
                break
            }
        }

        func presentComposer(referenceWindow: UIWindow?) {
            let plan = MBIssuePresentationPlan(
                isConfigured: configuration != nil,
                isInstalled: isInstalled,
                isPresenting: overlayWindow?.rootViewController?.presentedViewController != nil
            )
            var capturedImage: UIImage?
            var technicalContext: MBIssueTechnicalContext?

            for step in plan.steps {
                switch step {
                case .capture:
                    let sourceWindow = referenceWindow ?? self.referenceWindow
                    capturedImage = MBIssueCapture.screen(
                        referenceWindow: sourceWindow,
                        excluding: overlayWindow
                    )
                    if let configuration {
                        technicalContext = MBIssueCapture.technicalContext(
                            referenceWindow: sourceWindow,
                            excluding: overlayWindow,
                            environment: configuration.environment,
                            additional: configuration.additionalContext
                        )
                    }
                case .install:
                    install(referenceWindow: referenceWindow)
                case .presentComposer:
                    presentComposerContent(
                        capturedImage: capturedImage,
                        technicalContext: technicalContext
                    )
                }
            }
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

        private func presentComposerContent(
            capturedImage: UIImage? = nil,
            technicalContext: MBIssueTechnicalContext? = nil
        ) {
            guard let root = overlayWindow?.rootViewController,
                  root.presentedViewController == nil,
                  let configuration
            else {
                return
            }
            let capturedImage = capturedImage ?? MBIssueCapture.screen(
                referenceWindow: referenceWindow,
                excluding: overlayWindow
            )
            let technicalContext = technicalContext ?? MBIssueCapture.technicalContext(
                referenceWindow: referenceWindow,
                excluding: overlayWindow,
                environment: configuration.environment,
                additional: configuration.additionalContext
            )
            let view = MBIssueComposerView(
                capturedImage: capturedImage,
                projectKey: configuration.gateway.displayName,
                technicalContext: technicalContext,
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
                  let projectKey = configuration?.gateway.displayName
            else {
                return
            }
            let view = MBIssueListView(
                projectKey: projectKey,
                onClose: { [weak self] in self?.dismissPresented() },
                onNewIssue: { [weak self] in
                    self?.dismissPresented {
                        self?.presentComposerContent()
                    }
                },
                onRetry: { [weak self] id in self?.submit(id: id) },
                onOpen: { UIApplication.shared.open($0) },
                onExport: { [weak self] entries in self?.share(entries: entries) }
            )
            present(view.environmentObject(store), from: root)
        }

        private func present(_ view: some View, from root: UIViewController) {
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
            guard submissionTasks[id] == nil, let gatewayClient else { return }
            let task = Task { [weak self] in
                guard let self else { return }
                defer { submissionTasks[id] = nil }
                let submitter = MBIssueGatewaySubmitter(store: store, client: gatewayClient)
                await submitter.submit(ids: [id])
            }
            submissionTasks[id] = task
        }

        private func share(entries: [MBIssueEntry]) {
            guard !entries.isEmpty,
                  let root = overlayWindow?.rootViewController
            else {
                return
            }
            let presenter = topPresentedViewController(from: root)
            do {
                let screenshotURLs = Dictionary(uniqueKeysWithValues: entries.map { entry in
                    (entry.id, store.screenshotURLs(for: entry))
                })
                let archiveURL = try MBIssueReportBuilder.makeSharePackage(
                    entries: entries,
                    screenshotURLs: screenshotURLs
                )
                let activity = UIActivityViewController(
                    activityItems: [archiveURL],
                    applicationActivities: nil
                )
                activity.popoverPresentationController?.sourceView = presenter.view
                activity.popoverPresentationController?.sourceRect = CGRect(
                    x: presenter.view.bounds.midX,
                    y: presenter.view.bounds.maxY - 40,
                    width: 1,
                    height: 1
                )
                activity.completionWithItemsHandler = { _, _, _, _ in
                    try? FileManager.default.removeItem(at: archiveURL)
                }
                presenter.present(activity, animated: true)
            } catch {
                let alert = UIAlertController(
                    title: "Export failed",
                    message: error.localizedDescription,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .cancel))
                presenter.present(alert, animated: true)
            }
        }

        private func topPresentedViewController(from root: UIViewController) -> UIViewController {
            var current = root
            while let presented = current.presentedViewController {
                current = presented
            }
            return current
        }

        private func activeWindowScene() -> UIWindowScene? {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        }
    }
#endif
