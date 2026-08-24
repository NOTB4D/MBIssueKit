#if canImport(UIKit)
import SwiftUI

struct MBIssueFloatingBar: View {
    let onReport: () -> Void
    let onOpenList: () -> Void
    let onFrameChange: (CGRect) -> Void

    @EnvironmentObject private var store: MBIssueStore
    @State private var position = CGPoint.zero
    @State private var dragOrigin: CGPoint?
    @State private var pillSize = CGSize.zero
    @State private var isCollapsed = false
    @State private var hasPosition = false

    private let storageKey = "mbissuekit.floating-bar-position"

    var body: some View {
        GeometryReader { geometry in
            pill(in: geometry)
                .background(sizeReader)
                .position(position)
                .opacity(hasPosition ? 1 : 0)
                .onAppear { restorePosition(in: geometry) }
                .onChange(of: pillSize) { _ in position = clamped(position, in: geometry) }
        }
    }

    private func pill(in geometry: GeometryProxy) -> some View {
        HStack(spacing: 8) {
            dragHandle(in: geometry)
            if isCollapsed {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isCollapsed = false }
                } label: {
                    Image(systemName: "ladybug.fill")
                        .foregroundColor(MBIssueTheme.accent)
                        .frame(width: 28, height: 28)
                }
                .accessibilityLabel("Expand issue reporter")
            } else {
                Button(action: onReport) {
                    Label("REPORT", systemImage: "ladybug.fill")
                        .font(.caption.weight(.bold))
                        .foregroundColor(MBIssueTheme.accent)
                }
                divider
                Button(action: onOpenList) {
                    HStack(spacing: 5) {
                        Text("ISSUES")
                        Text("\(store.entries.count)")
                            .font(.caption2.monospacedDigit().weight(.bold))
                            .padding(.horizontal, 6)
                            .frame(height: 20)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                }
                divider
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isCollapsed = true }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 24, height: 24)
                }
                .accessibilityLabel("Collapse issue reporter")
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(Color(red: 0.055, green: 0.05, blue: 0.045).opacity(0.96))
        .clipShape(Capsule())
        .overlay { Capsule().stroke(MBIssueTheme.accent.opacity(0.45), lineWidth: 1) }
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 5)
    }

    private func dragHandle(in geometry: GeometryProxy) -> some View {
        VStack(spacing: 3) {
            ForEach(0 ..< 3, id: \.self) { _ in
                Capsule()
                    .fill(Color.white.opacity(0.38))
                    .frame(width: 11, height: 2)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .gesture(dragGesture(in: geometry))
        .accessibilityLabel("Move issue reporter")
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.16))
            .frame(width: 1, height: 16)
    }

    private var sizeReader: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    pillSize = proxy.size
                    reportFrame(proxy.frame(in: .global))
                }
                .onChange(of: proxy.size) { size in
                    pillSize = size
                    reportFrame(proxy.frame(in: .global))
                }
                .onChange(of: proxy.frame(in: .global)) { reportFrame($0) }
        }
    }

    private func dragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                let origin = dragOrigin ?? position
                if dragOrigin == nil { dragOrigin = position }
                position = clamped(
                    CGPoint(x: origin.x + value.translation.width, y: origin.y + value.translation.height),
                    in: geometry
                )
            }
            .onEnded { _ in
                dragOrigin = nil
                UserDefaults.standard.set([Double(position.x), Double(position.y)], forKey: storageKey)
            }
    }

    private func restorePosition(in geometry: GeometryProxy) {
        guard !hasPosition else { return }
        hasPosition = true
        if let stored = UserDefaults.standard.array(forKey: storageKey) as? [Double], stored.count == 2 {
            position = clamped(CGPoint(x: stored[0], y: stored[1]), in: geometry)
        } else {
            position = clamped(
                CGPoint(x: geometry.size.width - 118, y: geometry.size.height - 72),
                in: geometry
            )
        }
    }

    private func clamped(_ point: CGPoint, in geometry: GeometryProxy) -> CGPoint {
        let horizontal = pillSize.width / 2 + 8
        let vertical = pillSize.height / 2 + 8
        return CGPoint(
            x: min(max(point.x, horizontal), max(horizontal, geometry.size.width - horizontal)),
            y: min(max(point.y, vertical), max(vertical, geometry.size.height - vertical))
        )
    }

    private func reportFrame(_ frame: CGRect) {
        guard !frame.isEmpty else { return }
        onFrameChange(frame.insetBy(dx: -8, dy: -8))
    }
}
#endif
