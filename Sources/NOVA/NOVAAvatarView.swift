import AppKit

@MainActor
final class NOVAAvatarView: NSView {
    enum State {
        case idle
        case listening
        case thinking
        case speaking
    }

    var state: State = .idle {
        didSet { needsDisplay = true }
    }

    private var animationTimer: Timer?
    private var phase: CGFloat = 0

    override var isOpaque: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        startAnimation()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        startAnimation()
    }

    deinit {
        animationTimer?.invalidate()
    }

    private func startAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.phase += 0.055
            self.needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        defer { context.restoreGState() }

        let w = bounds.width
        let h = bounds.height
        let centerX = w * 0.5
        let bob = sin(phase) * 3.0
        let pulse = (sin(phase * 1.7) + 1.0) * 0.5

        // Soft holographic platform.
        drawEllipse(
            in: NSRect(x: centerX - 72, y: 18, width: 144, height: 22),
            fill: NSColor.systemCyan.withAlphaComponent(0.07),
            stroke: NSColor.systemCyan.withAlphaComponent(0.28),
            lineWidth: 1
        )
        drawEllipse(
            in: NSRect(x: centerX - 52, y: 22, width: 104, height: 10),
            fill: NSColor.clear,
            stroke: NSColor.systemCyan.withAlphaComponent(0.22),
            lineWidth: 1
        )

        context.saveGState()
        context.translateBy(x: 0, y: bob)

        let head = NSRect(x: centerX - 54, y: 205, width: 108, height: 118)
        let neck = NSRect(x: centerX - 24, y: 164, width: 48, height: 52)
        let shoulders = NSRect(x: centerX - 86, y: 55, width: 172, height: 128)

        // Glow layers.
        let glowAlpha = 0.06 + pulse * 0.025
        drawEllipse(in: head.insetBy(dx: -20, dy: -20), fill: NSColor.systemCyan.withAlphaComponent(glowAlpha), stroke: .clear, lineWidth: 0)
        drawEllipse(in: shoulders.insetBy(dx: -18, dy: -18), fill: NSColor.systemCyan.withAlphaComponent(glowAlpha * 0.65), stroke: .clear, lineWidth: 0)

        // Torso / shoulders.
        let torsoPath = NSBezierPath(roundedRect: shoulders, xRadius: 38, yRadius: 38)
        NSColor.systemCyan.withAlphaComponent(0.055).setFill()
        torsoPath.fill()
        NSColor.systemCyan.withAlphaComponent(0.58).setStroke()
        torsoPath.lineWidth = 1.4
        torsoPath.stroke()

        // Neck.
        let neckPath = NSBezierPath(roundedRect: neck, xRadius: 15, yRadius: 15)
        NSColor.systemCyan.withAlphaComponent(0.08).setFill()
        neckPath.fill()
        NSColor.systemCyan.withAlphaComponent(0.5).setStroke()
        neckPath.lineWidth = 1
        neckPath.stroke()

        // Head.
        let headPath = NSBezierPath(roundedRect: head, xRadius: 48, yRadius: 48)
        NSColor.systemCyan.withAlphaComponent(0.09).setFill()
        headPath.fill()
        NSColor.systemCyan.withAlphaComponent(0.72).setStroke()
        headPath.lineWidth = 1.6
        headPath.stroke()

        // Facial scan lines.
        for i in 0..<7 {
            let y = head.minY + 18 + CGFloat(i) * 13
            let scan = NSBezierPath()
            scan.move(to: NSPoint(x: head.minX + 17, y: y))
            scan.line(to: NSPoint(x: head.maxX - 17, y: y))
            NSColor.systemCyan.withAlphaComponent(0.11).setStroke()
            scan.lineWidth = 0.8
            scan.stroke()
        }

        // Eyes.
        let eyeY = head.midY + 5
        let eyeOffset: CGFloat = 21
        let eyeHeight: CGFloat = state == .listening ? 7 : 9
        drawEllipse(
            in: NSRect(x: centerX - eyeOffset - 9, y: eyeY - eyeHeight / 2, width: 18, height: eyeHeight),
            fill: NSColor.systemCyan.withAlphaComponent(0.86),
            stroke: .clear,
            lineWidth: 0
        )
        drawEllipse(
            in: NSRect(x: centerX + eyeOffset - 9, y: eyeY - eyeHeight / 2, width: 18, height: eyeHeight),
            fill: NSColor.systemCyan.withAlphaComponent(0.86),
            stroke: .clear,
            lineWidth: 0
        )

        // Mouth / voice indicator.
        let mouth = NSBezierPath()
        mouth.move(to: NSPoint(x: centerX - 17, y: head.minY + 32))
        mouth.curve(to: NSPoint(x: centerX + 17, y: head.minY + 32),
                    controlPoint1: NSPoint(x: centerX - 7, y: head.minY + 25),
                    controlPoint2: NSPoint(x: centerX + 7, y: head.minY + 25))
        NSColor.systemCyan.withAlphaComponent(0.62).setStroke()
        mouth.lineWidth = state == .speaking ? 2.4 : 1.2
        mouth.stroke()

        // Chest core.
        let coreRadius: CGFloat = 13 + pulse * 3
        drawEllipse(
            in: NSRect(x: centerX - coreRadius, y: 103 - coreRadius, width: coreRadius * 2, height: coreRadius * 2),
            fill: NSColor.systemCyan.withAlphaComponent(0.22),
            stroke: NSColor.systemCyan.withAlphaComponent(0.78),
            lineWidth: 1.2
        )

        // Floating hologram fragments.
        let fragmentCount = state == .idle ? 6 : 10
        for i in 0..<fragmentCount {
            let angle = phase * (0.35 + CGFloat(i % 3) * 0.08) + CGFloat(i) * 0.9
            let radius: CGFloat = 82 + CGFloat(i % 4) * 13
            let x = centerX + cos(angle) * radius
            let y = 154 + sin(angle * 1.13) * 105
            let size = 2.0 + CGFloat(i % 3)
            drawEllipse(
                in: NSRect(x: x - size / 2, y: y - size / 2, width: size, height: size),
                fill: NSColor.systemCyan.withAlphaComponent(0.35 + pulse * 0.18),
                stroke: .clear,
                lineWidth: 0
            )
        }

        // Listening ring.
        if state == .listening {
            let ringSize = 124 + pulse * 10
            let ring = NSRect(x: centerX - ringSize / 2, y: 202 - ringSize / 2, width: ringSize, height: ringSize)
            drawEllipse(in: ring, fill: .clear, stroke: NSColor.systemCyan.withAlphaComponent(0.28), lineWidth: 1.2)
        }

        context.restoreGState()

        // Label.
        let label = NSTextField(labelWithString: labelText)
        label.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        label.textColor = NSColor.systemCyan.withAlphaComponent(0.75)
        label.alignment = .center
        label.frame = NSRect(x: 40, y: 0, width: w - 80, height: 18)
        label.draw(label.bounds)
    }

    private var labelText: String {
        switch state {
        case .idle: return "NOVA • ONLINE"
        case .listening: return "NOVA • LISTENING"
        case .thinking: return "NOVA • THINKING"
        case .speaking: return "NOVA • SPEAKING"
        }
    }

    private func drawEllipse(in rect: NSRect, fill: NSColor, stroke: NSColor, lineWidth: CGFloat) {
        let path = NSBezierPath(ovalIn: rect)
        fill.setFill()
        path.fill()
        if lineWidth > 0 {
            stroke.setStroke()
            path.lineWidth = lineWidth
            path.stroke()
        }
    }
}

@MainActor
final class NOVAAvatarWindowController: NSWindowController {
    let avatarView: NOVAAvatarView

    init() {
        avatarView = NOVAAvatarView(frame: NSRect(x: 0, y: 0, width: 280, height: 390))

        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 390),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = true
        window.hidesOnDeactivate = false
        window.contentView = avatarView
        window.title = "NOVA Holographic Avatar"
        super.init(window: window)
    }

    required init?(coder: NSCoder) { nil }

    func showOnScreen() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let size = window?.frame.size ?? NSSize(width: 280, height: 390)
        let origin = NSPoint(
            x: visible.maxX - size.width - 34,
            y: visible.minY + 28
        )
        window?.setFrameOrigin(origin)
        window?.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }
}
