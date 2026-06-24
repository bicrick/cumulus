# Cumulus

A macOS menu-bar app that plays YouTube videos in a borderless, always-on-top overlay while you code.

## Features

- Borderless floating overlay above your IDE
- **Passive mode:** configurable resting opacity, click-through to apps below
- **Hover mode:** fades to configurable hover opacity, still click-through
- **Interactive mode:** hold Shift (configurable) while hovering to use YouTube controls
- Drag and resize in interactive mode
- Configurable opacity levels, modifier key, and transition speed
- Global hotkey: **Cmd+Shift+Y** to show/hide overlay
- Persists video URL, window position, and settings

## Requirements

- macOS 14.0+
- Xcode 15+

## Build

```bash
cd cumulus
xcodegen generate
xcodebuild -scheme Cumulus -configuration Debug build
```

Open `Cumulus.xcodeproj` in Xcode and run, or launch the built app from DerivedData.

## Usage

1. Launch Cumulus (menu bar icon: play.rectangle.on.rectangle)
2. Copy a YouTube URL and choose **Paste URL & Open**
3. Video appears as an overlay — click-through by default
4. Hover over the overlay to peek through at your IDE
5. Hold **Shift** while hovering to interact with YouTube controls
6. Open **Settings** (Cmd+,) to adjust opacity levels and modifier key

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| Resting opacity | 100% | When cursor is away |
| Hover opacity | 20% | When cursor is over overlay |
| Interactive opacity | 100% | When modifier key held |
| Interactive modifier | Shift | Key to enable YouTube controls |
| Transition | 150 ms | Fade duration between modes |
| Click-through | On | Passive/hover modes ignore mouse |
| Autoplay muted | On | Reliable autoplay on load |

## Keyboard shortcuts

- **Cmd+Shift+V** — Paste URL and open
- **Cmd+Shift+Y** — Toggle overlay visibility (global)
- **Cmd+,** — Settings
- **Cmd+Q** — Quit
