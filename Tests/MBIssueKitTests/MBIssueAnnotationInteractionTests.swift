import Foundation
@testable import MBIssueKit
import Testing

@Suite("Screenshot annotation interaction")
struct MBIssueAnnotationInteractionTests {
    @Test("Pen gestures produce normalized stroke points")
    func buildsStroke() {
        var interaction = MBIssueAnnotationInteraction()
        let size = CGSize(width: 200, height: 100)

        interaction.update(tool: .pen, location: CGPoint(x: 20, y: 25), canvasSize: size)
        interaction.update(tool: .pen, location: CGPoint(x: 180, y: 75), canvasSize: size)
        let result = interaction.finish(
            tool: .pen,
            location: CGPoint(x: 200, y: 100),
            canvasSize: size
        )

        #expect(result == .stroke([
            MBIssueNormalizedPoint(x: 0.1, y: 0.25),
            MBIssueNormalizedPoint(x: 0.9, y: 0.75),
            MBIssueNormalizedPoint(x: 1, y: 1),
        ]))
        #expect(interaction.isEmpty)
    }

    @Test("Text gestures produce a clamped insertion point")
    func buildsTextPoint() {
        var interaction = MBIssueAnnotationInteraction()

        let result = interaction.finish(
            tool: .text,
            location: CGPoint(x: 420, y: -20),
            canvasSize: CGSize(width: 300, height: 600)
        )

        #expect(result == .text(point: MBIssueNormalizedPoint(x: 1, y: 0)))
    }
}
