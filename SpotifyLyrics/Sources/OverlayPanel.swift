import AppKit

class OverlayPanel: NSPanel {

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Floating above all windows
        level = .floating
        isFloatingPanel = true

        // Transparent and non-opaque
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        // Don't hide when app deactivates
        hidesOnDeactivate = false

        // Allow dragging
        isMovableByWindowBackground = true

        // Don't show in mission control / expose
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        // Accept mouse events for dragging
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = false
    }

    // Allow the panel to become key for dragging, but not steal focus
    override var canBecomeKey: Bool { return false }
    override var canBecomeMain: Bool { return false }
}
