import Foundation
import AppKit
import Combine

class OverlaySettings: ObservableObject {

    static let shared = OverlaySettings()

    // MARK: - Font Size

    @Published var fontSize: CGFloat {
        didSet { UserDefaults.standard.set(Double(fontSize), forKey: "fontSize") }
    }

    // MARK: - Window Size

    @Published var windowWidth: CGFloat {
        didSet { UserDefaults.standard.set(Double(windowWidth), forKey: "windowWidth") }
    }

    @Published var windowHeight: CGFloat {
        didSet { UserDefaults.standard.set(Double(windowHeight), forKey: "windowHeight") }
    }

    // MARK: - Colors (stored as RGB components)

    @Published var currentLineColor: NSColor {
        didSet { saveColor(currentLineColor, key: "currentLineColor") }
    }

    @Published var otherLineColor: NSColor {
        didSet { saveColor(otherLineColor, key: "otherLineColor") }
    }

    @Published var backgroundColor: NSColor {
        didSet { saveColor(backgroundColor, key: "backgroundColor") }
    }

    @Published var backgroundOpacity: CGFloat {
        didSet { UserDefaults.standard.set(Double(backgroundOpacity), forKey: "backgroundOpacity") }
    }

    // MARK: - Computed

    var visibleLines: Int {
        // Estimate how many lines fit based on window height and font size
        let headerHeight: CGFloat = 50
        let padding: CGFloat = 30
        let lineSpacing: CGFloat = 6
        let available = windowHeight - headerHeight - padding
        let perLine = fontSize * 1.4 + lineSpacing
        return max(3, Int(available / perLine))
    }

    // MARK: - Init

    private init() {
        let defaults = UserDefaults.standard

        let fs = CGFloat(defaults.double(forKey: "fontSize"))
        fontSize = fs >= 1 ? fs : 16

        let ww = CGFloat(defaults.double(forKey: "windowWidth"))
        windowWidth = ww >= 1 ? ww : 320

        let wh = CGFloat(defaults.double(forKey: "windowHeight"))
        windowHeight = wh >= 1 ? wh : 300

        let bo = CGFloat(defaults.double(forKey: "backgroundOpacity"))
        backgroundOpacity = bo >= 0.01 ? bo : 0.95

        currentLineColor = OverlaySettings.loadColor(key: "currentLineColor") ?? .white
        otherLineColor = OverlaySettings.loadColor(key: "otherLineColor") ?? NSColor.white.withAlphaComponent(0.4)
        backgroundColor = OverlaySettings.loadColor(key: "backgroundColor") ?? NSColor.black
    }

    // MARK: - Color Persistence

    private func saveColor(_ color: NSColor, key: String) {
        let c = color.usingColorSpace(.sRGB) ?? color
        UserDefaults.standard.set(Double(c.redComponent), forKey: "\(key)_r")
        UserDefaults.standard.set(Double(c.greenComponent), forKey: "\(key)_g")
        UserDefaults.standard.set(Double(c.blueComponent), forKey: "\(key)_b")
        UserDefaults.standard.set(Double(c.alphaComponent), forKey: "\(key)_a")
        UserDefaults.standard.set(true, forKey: "\(key)_set")
    }

    private static func loadColor(key: String) -> NSColor? {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "\(key)_set") else { return nil }
        let r = CGFloat(defaults.double(forKey: "\(key)_r"))
        let g = CGFloat(defaults.double(forKey: "\(key)_g"))
        let b = CGFloat(defaults.double(forKey: "\(key)_b"))
        let a = CGFloat(defaults.double(forKey: "\(key)_a"))
        return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
    }

    // MARK: - Reset

    func resetToDefaults() {
        fontSize = 16
        windowWidth = 320
        windowHeight = 300
        backgroundOpacity = 0.95
        currentLineColor = .white
        otherLineColor = NSColor.white.withAlphaComponent(0.4)
        backgroundColor = .black
    }
}
