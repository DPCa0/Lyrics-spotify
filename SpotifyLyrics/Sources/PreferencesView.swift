import SwiftUI
import AppKit

struct PreferencesView: View {
    @ObservedObject var settings: OverlaySettings

    @State private var currentColor: Color
    @State private var otherColor: Color
    @State private var bgColor: Color

    init(settings: OverlaySettings) {
        self.settings = settings
        _currentColor = State(initialValue: Color(settings.currentLineColor))
        _otherColor = State(initialValue: Color(settings.otherLineColor))
        _bgColor = State(initialValue: Color(settings.backgroundColor))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preferences")
                .font(.system(size: 16, weight: .bold))

            // Font Size
            Group {
                Text("Font Size: \(Int(settings.fontSize))pt")
                    .font(.system(size: 12, weight: .medium))
                Slider(value: $settings.fontSize, in: 10...36, step: 1)
            }

            Divider()

            // Window Size
            Group {
                Text("Window Width: \(Int(settings.windowWidth))")
                    .font(.system(size: 12, weight: .medium))
                Slider(value: $settings.windowWidth, in: 200...800, step: 10)

                Text("Window Height: \(Int(settings.windowHeight))")
                    .font(.system(size: 12, weight: .medium))
                Slider(value: $settings.windowHeight, in: 150...800, step: 10)
            }

            Divider()

            // Colors
            Group {
                HStack {
                    Text("Current Line")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 100, alignment: .leading)
                    ColorPicker("", selection: $currentColor, supportsOpacity: true)
                        .labelsHidden()
                        .onChange(of: currentColor) { newVal in
                            settings.currentLineColor = NSColor(newVal)
                        }
                }

                HStack {
                    Text("Other Lines")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 100, alignment: .leading)
                    ColorPicker("", selection: $otherColor, supportsOpacity: true)
                        .labelsHidden()
                        .onChange(of: otherColor) { newVal in
                            settings.otherLineColor = NSColor(newVal)
                        }
                }

                HStack {
                    Text("Background")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 100, alignment: .leading)
                    ColorPicker("", selection: $bgColor, supportsOpacity: false)
                        .labelsHidden()
                        .onChange(of: bgColor) { newVal in
                            settings.backgroundColor = NSColor(newVal)
                        }
                }

                Text("Background Opacity: \(Int(settings.backgroundOpacity * 100))%")
                    .font(.system(size: 12, weight: .medium))
                Slider(value: $settings.backgroundOpacity, in: 0.1...1.0, step: 0.05)
            }

            Divider()

            HStack {
                Button("Reset to Defaults") {
                    settings.resetToDefaults()
                    currentColor = Color(settings.currentLineColor)
                    otherColor = Color(settings.otherLineColor)
                    bgColor = Color(settings.backgroundColor)
                }
                Spacer()
            }
        }
        .padding(20)
        .frame(width: 320)
    }
}
