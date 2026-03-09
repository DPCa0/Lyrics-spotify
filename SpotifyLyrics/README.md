# SpotifyLyrics

A lightweight macOS menu bar app that displays real-time synchronized lyrics for whatever is playing in Spotify.

![macOS 12+](https://img.shields.io/badge/macOS-12%2B-blue) ![Swift 5](https://img.shields.io/badge/Swift-5-orange) ![Apple Silicon](https://img.shields.io/badge/Arch-Apple%20Silicon-green)

## Features

- Live synced lyrics overlaid on your screen
- Transparent, always-on-top overlay window
- Customizable font size, colors, opacity, and window size
- Menu bar icon with quick toggle
- Settings persist across restarts

## Requirements

- macOS 12.0 (Monterey) or later
- Apple Silicon Mac (M1/M2/M3/M4)
- [Spotify desktop app](https://www.spotify.com/download/mac/)
- Xcode Command Line Tools

> **Intel Mac users:** Change `-target arm64-apple-macosx12.0` to `-target x86_64-apple-macosx12.0` in `build.sh` before building.

## Setup

### 1. Install Xcode Command Line Tools

If you haven't already:

```bash
xcode-select --install
```

### 2. Clone the repository

```bash
git clone https://github.com/YOUR_USERNAME/SpotifyLyrics.git
cd SpotifyLyrics
```

### 3. Build the app

```bash
chmod +x build.sh
./build.sh
```

This compiles all Swift sources and creates `build/SpotifyLyrics.app`.

### 4. Run the app

```bash
open build/SpotifyLyrics.app
```

Or double-click `build/SpotifyLyrics.app` in Finder.

The app will appear as a **♪** icon in your menu bar.

### 5. Get your Spotify `sp_dc` cookie

The app needs your `sp_dc` session cookie to fetch lyrics from Spotify's internal API.

1. Open [open.spotify.com](https://open.spotify.com) in your browser and log in
2. Open **Developer Tools** (F12 or Cmd+Option+I)
3. Go to **Application** → **Cookies** → `https://open.spotify.com`
4. Find the cookie named `sp_dc` and copy its value
5. In the app, click the **♪** menu bar icon → **Set sp_dc Cookie...**
6. Paste the value and click **OK**

> The cookie is stored locally in macOS `UserDefaults` and never leaves your machine.

## Usage

| Action | How |
|---|---|
| Toggle overlay | Click **♪** → **Toggle Overlay** |
| Customize appearance | Click **♪** → **Preferences...** |
| Update cookie | Click **♪** → **Set sp_dc Cookie...** |
| Quit | Click **♪** → **Quit** |

The overlay appears in the **bottom-right corner** of your primary display. You can drag it to reposition.

## How it works

1. Polls the Spotify desktop app every 0.5 seconds via **AppleScript** to get the current track ID and playback position
2. Fetches time-synced lyrics from Spotify's internal lyrics API using your `sp_dc` cookie
3. Renders the lyrics overlay as a floating transparent window, highlighting the current line in real time

## Privacy

- No data is sent anywhere except to Spotify's own servers (to fetch lyrics for your currently playing track)
- Your `sp_dc` cookie is stored only on your local machine in `UserDefaults`
- No analytics, no tracking

## Troubleshooting

**Overlay shows "Set sp_dc cookie from menu bar"**
→ Follow Step 5 above to add your cookie.

**Overlay shows "No lyrics available"**
→ The current track doesn't have synced lyrics in Spotify's database. Not all songs have them.

**Overlay shows "Spotify is not running"**
→ Launch the Spotify desktop app.

**Build fails**
→ Make sure Xcode Command Line Tools are installed: `xcode-select --install`

**Cookie stops working**
→ Spotify session cookies expire. Log out and back in to open.spotify.com, grab a fresh `sp_dc` value, and update it via the menu.

## License

MIT
