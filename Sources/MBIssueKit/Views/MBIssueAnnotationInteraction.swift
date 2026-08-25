import Foundation

enum MBIssueAnnotationTool: String, CaseIterable, Identifiable, Sendable {
    case pen
    case arrow
    case rectangle
    case text

    var id: String {
        rawValue
    }

    var systemImage: String {
        switch self {
        case .pen: return "pencil.tip"
        case .arrow: return "arrow.up.right"
        case .rectangle: return "rectangle"
        case .text: return "textformat"
        }
    }

    var accessibilityName: String {
        switch self {
        case .pen: return "Pen"
        case .arrow: return "Arrow"
        case .rectangle: return "Rectangle"
        case .text: return "Text"
        }
    }
}

struct MBIssueNormalizedPoint: Equatable, Sendable {
    let x: CGFloat
    let y: CGFloat

    var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

enum MBIssueAnnotationGestureResult: Equatable, Sendable {
    case stroke([MBIssueNormalizedPoint])
    case arrow(start: MBIssueNormalizedPoint, end: MBIssueNormalizedPoint)
    case rectangle(start: MBIssueNormalizedPoint, end: MBIssueNormalizedPoint)
    case text(point: MBIssueNormalizedPoint)
}

struct MBIssueAnnotationInteraction: Sendable {
    private(set) var points: [MBIssueNormalizedPoint] = []
    private(set) var start: MBIssueNormalizedPoint?
    private(set) var current: MBIssueNormalizedPoint?

    var isEmpty: Bool {
        points.isEmpty && start == nil && current == nil
    }

    mutating func update(
        tool: MBIssueAnnotationTool,
        location: CGPoint,
        canvasSize: CGSize
    ) {
        let point = normalized(location, in: canvasSize)
        switch tool {
        case .pen:
            if points.last != point {
                points.append(point)
            }
        case .arrow, .rectangle, .text:
            start = start ?? point
            current = point
        }
    }

    mutating func finish(
        tool: MBIssueAnnotationTool,
        location: CGPoint,
        canvasSize: CGSize
    ) -> MBIssueAnnotationGestureResult? {
        update(tool: tool, location: location, canvasSize: canvasSize)
        defer { reset() }

        switch tool {
        case .pen:
            guard points.count > 1 else { return nil }
            return .stroke(points)
        case .arrow:
            guard let start, let current else { return nil }
            return .arrow(start: start, end: current)
        case .rectangle:
            guard let start, let current else { return nil }
            return .rectangle(start: start, end: current)
        case .text:
            guard let current else { return nil }
            return .text(point: current)
        }
    }

    private mutating func reset() {
        points = []
        start = nil
        current = nil
    }

    private func normalized(_ point: CGPoint, in size: CGSize) -> MBIssueNormalizedPoint {
        MBIssueNormalizedPoint(
            x: min(max(point.x / max(size.width, 1), 0), 1),
            y: min(max(point.y / max(size.height, 1), 0), 1)
        )
    }
}
