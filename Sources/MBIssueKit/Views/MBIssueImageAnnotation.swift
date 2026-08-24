#if canImport(UIKit)
import SwiftUI
import UIKit

enum MBIssueAnnotationTool: String, CaseIterable, Identifiable {
    case pen
    case arrow
    case rectangle
    case text

    var id: String { rawValue }

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

enum MBIssueAnnotationColor: String, CaseIterable, Identifiable {
    case orange
    case red
    case green
    case blue
    case white
    case black

    var id: String { rawValue }

    var uiColor: UIColor {
        switch self {
        case .orange: return UIColor(red: 0.96, green: 0.58, blue: 0.08, alpha: 1)
        case .red: return UIColor.systemRed
        case .green: return UIColor.systemGreen
        case .blue: return UIColor.systemBlue
        case .white: return UIColor.white
        case .black: return UIColor.black
        }
    }

    var color: Color { Color(uiColor) }
}

struct MBIssueImageAnnotation: Identifiable {
    let id = UUID()
    let content: Content
    let color: MBIssueAnnotationColor

    enum Content {
        case stroke([CGPoint])
        case arrow(start: CGPoint, end: CGPoint)
        case rectangle(start: CGPoint, end: CGPoint)
        case text(String, point: CGPoint)
    }
}

enum MBIssueAnnotationRenderer {
    static func render(
        image: UIImage,
        annotations: [MBIssueImageAnnotation]
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: image.size, format: format).image { context in
            image.draw(in: CGRect(origin: .zero, size: image.size))
            for annotation in annotations {
                draw(annotation, size: image.size, context: context.cgContext)
            }
        }
    }

    private static func draw(
        _ annotation: MBIssueImageAnnotation,
        size: CGSize,
        context: CGContext
    ) {
        let color = annotation.color.uiColor
        context.setStrokeColor(color.cgColor)
        context.setFillColor(color.cgColor)
        context.setLineWidth(max(4, min(size.width, size.height) * 0.008))
        context.setLineCap(.round)
        context.setLineJoin(.round)

        switch annotation.content {
        case let .stroke(points):
            guard let first = points.first else { return }
            context.beginPath()
            context.move(to: denormalize(first, size: size))
            points.dropFirst().forEach { context.addLine(to: denormalize($0, size: size)) }
            context.strokePath()
        case let .rectangle(start, end):
            let start = denormalize(start, size: size)
            let end = denormalize(end, size: size)
            context.stroke(CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            ))
        case let .arrow(start, end):
            drawArrow(
                from: denormalize(start, size: size),
                to: denormalize(end, size: size),
                context: context
            )
        case let .text(value, point):
            let point = denormalize(point, size: size)
            let fontSize = max(18, min(size.width, size.height) * 0.045)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
                .foregroundColor: color,
                .strokeColor: UIColor.black.withAlphaComponent(0.6),
                .strokeWidth: -2
            ]
            value.draw(at: point, withAttributes: attributes)
        }
    }

    private static func drawArrow(from start: CGPoint, to end: CGPoint, context: CGContext) {
        context.beginPath()
        context.move(to: start)
        context.addLine(to: end)
        let angle = atan2(end.y - start.y, end.x - start.x)
        let length: CGFloat = 24
        context.move(to: end)
        context.addLine(to: CGPoint(
            x: end.x - length * cos(angle - .pi / 6),
            y: end.y - length * sin(angle - .pi / 6)
        ))
        context.move(to: end)
        context.addLine(to: CGPoint(
            x: end.x - length * cos(angle + .pi / 6),
            y: end.y - length * sin(angle + .pi / 6)
        ))
        context.strokePath()
    }

    private static func denormalize(_ point: CGPoint, size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }
}
#endif
