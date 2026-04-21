# LotaView

Native RTSP surveillance viewer for macOS with hardware-accelerated decoding and zero third-party dependencies.

<!-- ![LotaView Screenshot](screenshots/lotaview-preview.png) -->

## Download

**[LotaView-1.0.4-macOS.dmg](https://github.com/belzebu/LotaView/releases/download/v1.0.4/LotaView-1.0.4-macOS.dmg)** — macOS 14.0+

> **First launch:** macOS will show "Apple cannot verify this app" since it is not notarized. To open:
>
> **Option A:** Right-click the app → Open → click "Open" in the dialog
>
> **Option B:** Run in Terminal:
> ```bash
> xattr -cr /Applications/LotaView.app
> ```
> This only needs to be done once.

## Features

- **Multi-Dashboard** — Create multiple dashboards, each with independent camera selection
- **Flexible Grid Layout** — 1, 2, 4, 6, 8, or 9 cameras per dashboard (auto-adapting grid)
- **Native RTSP Client** — Custom RTSP protocol implementation using Network.framework (no VLC, no FFmpeg)
- **Hardware Decoding** — VideoToolbox `VTDecompressionSession` for H.264 and H.265
- **Zero-Copy Rendering** — `AVSampleBufferDisplayLayer` direct pixel buffer display
- **Digest Authentication** — Hikvision/Dahua-compatible RTSP digest auth (MD5)
- **RTP over TCP** — Interleaved transport for reliable streaming through firewalls
- **Camera Management** — Add, edit, delete cameras with SwiftData persistence
- **Light / Dark Mode** — Follows system appearance or manual override in Settings
- **Multilingual** — English and Traditional Chinese (繁體中文)
- **Zero Dependencies** — Pure Apple frameworks, no CocoaPods/SPM packages

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        SwiftUI Views                         │
│  LiveDashboardView  ·  CameraManagement  ·  CameraFormSheet  │
├─────────────────────────────────────────────────────────────┤
│                        ViewModels                            │
│          GridViewModel  ·  CameraManagerViewModel            │
├─────────────────────────────────────────────────────────────┤
│                     PlayerWrapper                            │
│         Ties RTSPClient + VideoDecoder + DisplayLayer         │
├──────────────┬──────────────────┬────────────────────────────┤
│  RTSPClient  │   VideoDecoder   │  AVSampleBufferDisplayLayer │
│              │                  │                            │
│  NWConnection│  VTDecompression │  Zero-copy CVPixelBuffer    │
│  RTSP/SDP    │  Session         │  rendering                 │
│  RTP depack  │  H.264 / H.265  │                            │
│  Digest auth │  Hardware accel  │                            │
└──────────────┴──────────────────┴────────────────────────────┘
```

### Data Flow

```
NWConnection (TCP)
  → RTSP DESCRIBE/SETUP/PLAY
    → SDP parsing (codec, SPS/PPS/VPS)
      → RTP interleaved receive
        → H.264 FU-A/STAP-A or H.265 FU/AP depacketization
          → VideoToolbox hardware decode
            → CVPixelBuffer → CMSampleBuffer
              → AVSampleBufferDisplayLayer (zero-copy)
```

## Supported Formats

| Feature | Support |
|---------|---------|
| H.264 (AVC) | Full — SPS/PPS from SDP and in-band |
| H.265 (HEVC) | Full — VPS/SPS/PPS from SDP and in-band |
| Transport | RTP/AVP/TCP (interleaved) |
| Authentication | Digest (MD5) — Hikvision, Dahua, etc. |
| Audio | Not decoded (surveillance use case) |

## Requirements

- macOS 14.0+
- Xcode 16.0+ (for building from source)
- No third-party dependencies

## Build from Source

```bash
git clone https://github.com/belzebu/LotaView.git
cd LotaView

# Generate Xcode project (requires xcodegen)
brew install xcodegen
xcodegen generate

# Open and build
open LotaView.xcodeproj
```

Select the **LotaView-macOS** scheme, then build and run.

## Project Structure

```
RTSPViewer/
├── App/
│   └── RTSPViewerApp.swift          # App entry point + SwiftData container
├── Models/
│   ├── Camera.swift                  # SwiftData @Model with credentials
│   ├── Dashboard.swift               # SwiftData @Model for dashboard layouts
│   └── StreamStatus.swift            # Connection state enum
├── Services/
│   ├── RTSPClient.swift              # RTSP protocol + SDP + RTP + digest auth
│   ├── VideoDecoder.swift            # VideoToolbox H.264/H.265 hardware decoder
│   ├── PlayerWrapper.swift           # Integration: RTSP → Decode → Display
│   └── StreamEngine.swift            # Actor managing player lifecycles
├── ViewModels/
│   ├── GridViewModel.swift           # Dynamic grid state + reconnect logic
│   └── CameraManagerViewModel.swift  # Camera CRUD operations
├── Views/
│   ├── RootView.swift                # App shell (TabView iOS / SplitView macOS)
│   ├── SidebarView.swift             # macOS sidebar navigation
│   ├── LiveDashboardView.swift       # 2x2 live grid with header
│   ├── StreamCellView.swift          # Single grid cell with gradient overlay
│   ├── StreamPlayerView.swift        # UIViewRepresentable / NSViewRepresentable
│   ├── FullscreenPlayerView.swift    # Fullscreen with tap-to-toggle controls
│   ├── CameraManagementView.swift    # Camera list with stats cards
│   ├── CameraFormSheet.swift         # Add/Edit camera modal
│   └── CameraPickerView.swift        # Camera selection for grid slots
└── Utilities/
    ├── Constants.swift               # Buffer durations, grid dimensions
    ├── PlatformTypes.swift           # UIView/NSView typealiases
    └── Theme.swift                   # Design system colors
```

## License

MIT License. See [LICENSE](LICENSE) for details.

## Author

LotaView Team
