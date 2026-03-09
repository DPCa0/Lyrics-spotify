import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var overlayPanel: OverlayPanel?
    private var syncEngine: LyricsSyncEngine!
    private var settings: OverlaySettings!
    private var overlayVisible = false
    private var preferencesWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Load saved cookie
        SpotifyLyricsAPI.shared.loadSavedCookie()

        // Download latest TOTP secrets
        SpotifyTOTP.downloadSecrets {}

        // Create settings and sync engine
        settings = OverlaySettings.shared
        syncEngine = LyricsSyncEngine()

        // Watch for size changes to resize the panel
        Publishers.CombineLatest(settings.$windowWidth, settings.$windowHeight)
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { [weak self] width, height in
                self?.resizeOverlay(width: width, height: height)
            }
            .store(in: &cancellables)

        // Setup menu bar
        setupMenuBar()

        // Show overlay and start engine
        showOverlay()
        syncEngine.start()

        // Prompt for cookie if not set
        if !SpotifyLyricsAPI.shared.hasCookie() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.promptForCookie()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        syncEngine.stop()
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "♪"
        }

        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: "Toggle Overlay", action: #selector(toggleOverlay), keyEquivalent: "l")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        let cookieItem = NSMenuItem(title: "Set sp_dc Cookie...", action: #selector(promptForCookie), keyEquivalent: "")
        cookieItem.target = self
        menu.addItem(cookieItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Overlay

    private func showOverlay() {
        guard overlayPanel == nil else {
            overlayPanel?.orderFront(nil)
            overlayVisible = true
            return
        }

        let w = settings.windowWidth
        let h = settings.windowHeight

        // Position in bottom-right area of screen
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let x = screenFrame.maxX - w - 40
        let y = screenFrame.minY + 40

        let panel = OverlayPanel(contentRect: NSRect(x: x, y: y, width: w, height: h))

        let hostingView = NSHostingView(rootView: LyricsOverlayView(engine: syncEngine, settings: settings))
        hostingView.frame = NSRect(x: 0, y: 0, width: w, height: h)
        panel.contentView = hostingView

        panel.orderFront(nil)
        overlayPanel = panel
        overlayVisible = true
    }

    private func hideOverlay() {
        overlayPanel?.orderOut(nil)
        overlayVisible = false
    }

    private func resizeOverlay(width: CGFloat, height: CGFloat) {
        guard let panel = overlayPanel else { return }
        var frame = panel.frame
        // Keep the top-left corner in place
        let oldTop = frame.origin.y + frame.size.height
        frame.size.width = width
        frame.size.height = height
        frame.origin.y = oldTop - height
        panel.setFrame(frame, display: true, animate: true)
        panel.contentView?.frame = NSRect(x: 0, y: 0, width: width, height: height)
    }

    @objc private func toggleOverlay() {
        if overlayVisible {
            hideOverlay()
        } else {
            showOverlay()
        }
    }

    // MARK: - Preferences

    @objc private func showPreferences() {
        if let existingWindow = preferencesWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let prefsView = PreferencesView(settings: settings)
        let hostingController = NSHostingController(rootView: prefsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "SpotifyLyrics Preferences"
        window.styleMask = [.titled, .closable]
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        preferencesWindow = window
    }

    // MARK: - Cookie Prompt

    @objc func promptForCookie() {
        let alert = NSAlert()
        alert.messageText = "Spotify sp_dc Cookie"
        alert.informativeText = "Enter your sp_dc cookie value from open.spotify.com.\n\n1. Open open.spotify.com in your browser\n2. Log in if needed\n3. Open Developer Tools \u{2192} Application \u{2192} Cookies\n4. Find the 'sp_dc' cookie and copy its value"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 340, height: 24))
        input.placeholderString = "Paste sp_dc cookie value here"
        input.stringValue = SpotifyLyricsAPI.shared.getCookie()
        alert.accessoryView = input

        // Bring app to front for the dialog
        NSApp.activate(ignoringOtherApps: true)

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let cookie = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cookie.isEmpty {
                SpotifyLyricsAPI.shared.setCookie(cookie)
                SpotifyLyricsAPI.shared.clearLyricsCache()
            }
        }
    }

    // MARK: - Quit

    @objc private func quitApp() {
        syncEngine.stop()
        NSApp.terminate(nil)
    }
}
