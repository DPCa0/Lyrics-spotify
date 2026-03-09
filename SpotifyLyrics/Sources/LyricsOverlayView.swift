import SwiftUI

struct LyricsOverlayView: View {
    @ObservedObject var engine: LyricsSyncEngine
    @ObservedObject var settings: OverlaySettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Track info header
            if !engine.trackName.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(engine.trackName)
                        .font(.system(size: settings.fontSize * 0.75, weight: .semibold))
                        .foregroundColor(Color(settings.currentLineColor).opacity(0.9))
                        .lineLimit(1)
                    Text(engine.artistName)
                        .font(.system(size: settings.fontSize * 0.7, weight: .regular))
                        .foregroundColor(Color(settings.otherLineColor))
                        .lineLimit(1)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }

            // Lyrics or status
            if engine.hasLyrics {
                lyricsContent
            } else {
                statusContent
            }
        }
        .frame(width: settings.windowWidth, height: settings.windowHeight)
        .background(
            Color(settings.backgroundColor)
                .opacity(settings.backgroundOpacity)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color(settings.currentLineColor).opacity(0.1), lineWidth: 0.5)
        )
    }

    private var lyricsContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(displayRange, id: \.self) { index in
                let isCurrent = index == engine.currentIndex
                Text(engine.lines[index].words)
                    .font(.system(size: isCurrent ? settings.fontSize : settings.fontSize * 0.875,
                                  weight: isCurrent ? .bold : .regular))
                    .foregroundColor(isCurrent ? Color(settings.currentLineColor)
                                               : Color(settings.otherLineColor))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.easeInOut(duration: 0.3), value: engine.currentIndex)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var statusContent: some View {
        VStack {
            Spacer()
            Text(engine.statusMessage)
                .font(.system(size: settings.fontSize * 0.875, weight: .medium))
                .foregroundColor(Color(settings.otherLineColor))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    /// Compute which lines to display, centered around current index
    private var displayRange: Range<Int> {
        let total = engine.lines.count
        guard total > 0 else { return 0..<0 }

        let vis = settings.visibleLines
        let current = max(0, engine.currentIndex)
        let half = vis / 2

        var start = current - half
        var end = current + half + 1

        if start < 0 {
            end = min(total, end - start)
            start = 0
        }
        if end > total {
            start = max(0, start - (end - total))
            end = total
        }

        return start..<end
    }
}

// MARK: - NSVisualEffectView wrapper for SwiftUI

struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
