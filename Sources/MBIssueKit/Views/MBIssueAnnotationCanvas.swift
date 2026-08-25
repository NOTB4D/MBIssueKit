#if canImport(UIKit)
    import SwiftUI

    struct MBIssueAnnotationCanvas: View {
        let annotations: [MBIssueImageAnnotation]
        let tool: MBIssueAnnotationTool
        let color: MBIssueAnnotationColor
        let onAnnotation: (MBIssueImageAnnotation) -> Void
        let onTextPoint: (CGPoint) -> Void

        @State private var interaction = MBIssueAnnotationInteraction()

        var body: some View {
            GeometryReader { geometry in
                ZStack {
                    Color.clear
                    ForEach(annotations) { annotation in
                        annotationView(annotation, size: geometry.size)
                    }
                    preview(size: geometry.size)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(drawingGesture(size: geometry.size))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Screenshot canvas")
                .accessibilityIdentifier("mbissue.annotation-canvas")
            }
        }

        @ViewBuilder
        private func annotationView(_ annotation: MBIssueImageAnnotation, size: CGSize) -> some View {
            switch annotation.content {
            case let .stroke(points):
                strokePath(points, size: size)
                    .stroke(annotation.color.color, style: lineStyle)
            case let .arrow(start, end):
                arrowPath(start: start, end: end, size: size)
                    .stroke(annotation.color.color, style: lineStyle)
            case let .rectangle(start, end):
                rectanglePath(start: start, end: end, size: size)
                    .stroke(annotation.color.color, style: lineStyle)
            case let .text(value, point):
                Text(value)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundColor(annotation.color.color)
                    .shadow(color: .black.opacity(0.75), radius: 1)
                    .position(denormalize(point, size: size))
            }
        }

        @ViewBuilder
        private func preview(size: CGSize) -> some View {
            if tool == .pen, !interaction.points.isEmpty {
                strokePath(interaction.points.map(\.cgPoint), size: size)
                    .stroke(color.color, style: lineStyle)
            } else if let start = interaction.start, let current = interaction.current {
                if tool == .arrow {
                    arrowPath(start: start.cgPoint, end: current.cgPoint, size: size)
                        .stroke(color.color, style: lineStyle)
                } else if tool == .rectangle {
                    rectanglePath(start: start.cgPoint, end: current.cgPoint, size: size)
                        .stroke(color.color, style: lineStyle)
                }
            }
        }

        private var lineStyle: StrokeStyle {
            StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
        }

        private func drawingGesture(size: CGSize) -> some Gesture {
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    interaction.update(tool: tool, location: value.location, canvasSize: size)
                }
                .onEnded { value in
                    switch interaction.finish(tool: tool, location: value.location, canvasSize: size) {
                    case let .stroke(points):
                        onAnnotation(.init(content: .stroke(points.map(\.cgPoint)), color: color))
                    case let .arrow(start, end):
                        onAnnotation(.init(content: .arrow(start: start.cgPoint, end: end.cgPoint), color: color))
                    case let .rectangle(start, end):
                        onAnnotation(.init(content: .rectangle(start: start.cgPoint, end: end.cgPoint), color: color))
                    case let .text(point):
                        onTextPoint(point.cgPoint)
                    case nil:
                        break
                    }
                }
        }

        private func strokePath(_ points: [CGPoint], size: CGSize) -> Path {
            var path = Path()
            guard let first = points.first else { return path }
            path.move(to: denormalize(first, size: size))
            points.dropFirst().forEach { path.addLine(to: denormalize($0, size: size)) }
            return path
        }

        private func rectanglePath(start: CGPoint, end: CGPoint, size: CGSize) -> Path {
            let start = denormalize(start, size: size)
            let end = denormalize(end, size: size)
            return Path(CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            ))
        }

        private func arrowPath(start: CGPoint, end: CGPoint, size: CGSize) -> Path {
            let start = denormalize(start, size: size)
            let end = denormalize(end, size: size)
            let angle = atan2(end.y - start.y, end.x - start.x)
            let length: CGFloat = 22
            var path = Path()
            path.move(to: start)
            path.addLine(to: end)
            path.move(to: end)
            path.addLine(to: CGPoint(
                x: end.x - length * cos(angle - .pi / 6),
                y: end.y - length * sin(angle - .pi / 6)
            ))
            path.move(to: end)
            path.addLine(to: CGPoint(
                x: end.x - length * cos(angle + .pi / 6),
                y: end.y - length * sin(angle + .pi / 6)
            ))
            return path
        }

        private func denormalize(_ point: CGPoint, size: CGSize) -> CGPoint {
            CGPoint(x: point.x * size.width, y: point.y * size.height)
        }
    }
#endif
