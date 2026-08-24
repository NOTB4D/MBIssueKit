#if canImport(UIKit)
import PhotosUI
import SwiftUI
import UIKit

struct MBIssuePhotoPicker: UIViewControllerRepresentable {
    let onSelection: ([UIImage]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelection: onSelection)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 0
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onSelection: ([UIImage]) -> Void

        init(onSelection: @escaping ([UIImage]) -> Void) {
            self.onSelection = onSelection
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard !results.isEmpty else {
                return
            }

            let group = DispatchGroup()
            let collector = ImageCollector()
            for (index, result) in results.enumerated() {
                guard result.itemProvider.canLoadObject(ofClass: UIImage.self) else {
                    continue
                }
                group.enter()
                result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                    defer { group.leave() }
                    guard let image = object as? UIImage else {
                        return
                    }
                    collector.append(image, at: index)
                }
            }
            group.notify(queue: .main) { [onSelection] in
                onSelection(collector.sortedImages())
            }
        }
    }
}

private final class ImageCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [(Int, UIImage)] = []

    func append(_ image: UIImage, at index: Int) {
        lock.lock()
        values.append((index, image))
        lock.unlock()
    }

    func sortedImages() -> [UIImage] {
        lock.lock()
        defer { lock.unlock() }
        return values.sorted { $0.0 < $1.0 }.map(\.1)
    }
}
#endif
