import SwiftUI
import AppKit

// MARK: - Pulsing Red Dot

struct PulsingDot: View {
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 9, height: 9)
            .shadow(color: .red.opacity(0.6), radius: isPulsing ? 6 : 2)
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .animation(
                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}

// MARK: - RecordingOverlayView

struct RecordingOverlayView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        HStack(spacing: 8) {
            PulsingDot()

            Image(systemName: "mic.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.85))

            Text(formatDuration(appState.recordingDuration))
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
                .frame(minWidth: 44, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(
            Capsule()
                .fill(.ultraThinMaterial.opacity(0.6))
                .overlay(
                    Capsule()
                        .fill(Color.black.opacity(0.25))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                )
        )
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - RecordingOverlayPanel

final class RecordingOverlayPanel: NSPanel {
    private let hostingView: NSHostingView<RecordingOverlayView>

    init(appState: AppState) {
        let overlayView = RecordingOverlayView(appState: appState)
        hostingView = NSHostingView(rootView: overlayView)

        // Wide enough to show "0:00" through "59:59" without clipping
        let panelWidth: CGFloat = 200
        let panelHeight: CGFloat = 50

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        contentView = hostingView
        hostingView.frame = contentView!.bounds
        hostingView.autoresizingMask = [.width, .height]

        positionAtBottomCenter()
    }

    private func positionAtBottomCenter() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let panelWidth: CGFloat = 200
        let panelHeight: CGFloat = 50
        let x = screenFrame.origin.x + (screenFrame.width - panelWidth) / 2
        let y = screenFrame.origin.y + 60
        setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
    }

    func showWithAnimation() {
        alphaValue = 0
        positionAtBottomCenter()
        orderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            self.animator().alphaValue = 1.0
        }
    }

    func hideWithAnimation() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            self.animator().alphaValue = 0.0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }
}
