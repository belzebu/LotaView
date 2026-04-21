#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import AVFoundation
import CoreMedia

// MARK: - Delegate

protocol PlayerWrapperDelegate: AnyObject {
    func playerDidChangeState(_ wrapper: PlayerWrapper, state: StreamStatus)
}

// MARK: - Display View

/// View backed by AVSampleBufferDisplayLayer for zero-copy frame display.
#if os(iOS)
final class SampleBufferDisplayView: UIView {
    override class var layerClass: AnyClass { AVSampleBufferDisplayLayer.self }
    var displayLayer: AVSampleBufferDisplayLayer { layer as! AVSampleBufferDisplayLayer }
}
#elseif os(macOS)
final class SampleBufferDisplayView: NSView {
    private let _displayLayer = AVSampleBufferDisplayLayer()

    var displayLayer: AVSampleBufferDisplayLayer { _displayLayer }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer = _displayLayer
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}
#endif

// MARK: - Player Wrapper

/// Native RTSP player: RTSPClient → VideoDecoder → AVSampleBufferDisplayLayer.
/// Thread safety: all mutable state accessed on mediaQueue or main thread.
final class PlayerWrapper: NSObject, @unchecked Sendable {
    let playerID: UUID
    weak var delegate: PlayerWrapperDelegate?

    private let rtspClient = RTSPClient()
    private let decoder = VideoDecoder()
    private let displayView = SampleBufferDisplayView()
    private let mediaQueue = DispatchQueue(label: "com.lotalink.lotaview.player", qos: .userInitiated)

    private(set) var status: StreamStatus = .idle {
        didSet {
            delegate?.playerDidChangeState(self, state: status)
        }
    }

    private var connectTime: Date?
    private var isRestarting = false

    override init() {
        self.playerID = UUID()
        super.init()

        #if os(iOS)
        displayView.backgroundColor = .black
        #elseif os(macOS)
        displayView.wantsLayer = true
        displayView.layer?.backgroundColor = NSColor.black.cgColor
        #endif
        displayView.displayLayer.videoGravity = .resizeAspect

        setupCallbacks()
    }

    private var lastURL: String?
    private var lastBufferDuration: Int = AppConstants.gridBufferDuration

    var view: PlatformView { displayView }

    // MARK: - Public API

    func play(url: String, bufferDuration: Int = AppConstants.gridBufferDuration) {

        guard URL(string: url) != nil else {
            DispatchQueue.main.async { self.status = .error("Invalid URL: \(url)") }
            return
        }

        lastURL = url
        lastBufferDuration = bufferDuration
        connectTime = Date()

        // Suppress callbacks during cleanup to prevent reconnect loop.
        // Set flag BEFORE disconnect; clear it AFTER new connect starts.
        // The flag stays true across the async disconnect/cancel callbacks.
        isRestarting = true
        rtspClient.disconnect()
        decoder.invalidate()

        DispatchQueue.main.async {
            self.displayView.displayLayer.flush()
            self.status = .connecting
        }

        // Small delay lets NWConnection.cancel() callbacks drain before we reconnect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            self.isRestarting = false
            self.rtspClient.connect(url: url)
        }
    }

    func stop() {
        rtspClient.disconnect()
        decoder.invalidate()

        DispatchQueue.main.async {
            self.displayView.displayLayer.flushAndRemoveImage()
            self.status = .stopped
        }
    }

    func setFullscreen(_ fullscreen: Bool) {
        // Native pipeline handles resolution natively — no reconfiguration needed.
    }

    func snapshot() -> PlatformImage? {
        #if os(iOS)
        let renderer = UIGraphicsImageRenderer(bounds: displayView.bounds)
        return renderer.image { ctx in
            displayView.layer.render(in: ctx.cgContext)
        }
        #elseif os(macOS)
        guard let layer = displayView.layer else { return nil }
        let size = displayView.bounds.size
        guard size.width > 0, size.height > 0 else { return nil }
        let image = NSImage(size: size)
        image.lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            layer.render(in: ctx)
        }
        image.unlockFocus()
        return image
        #endif
    }

    deinit {
        rtspClient.disconnect()
        decoder.invalidate()
    }

    // MARK: - Internal Wiring

    private func setupCallbacks() {
        rtspClient.onStateChange = { [weak self] rtspState in
            guard let self, !self.isRestarting else { return }

            let newStatus: StreamStatus = switch rtspState {
            case .disconnected: .stopped
            case .connecting, .describing, .setup: .connecting
            case .playing: .playing
            case .error(let msg): .error(msg)
            }

            #if DEBUG
            if case .playing = newStatus, let start = self.connectTime {
                let elapsed = Date().timeIntervalSince(start)
                print("[Player] Playing in \(String(format: "%.1f", elapsed))s")
            }
            #endif

            DispatchQueue.main.async { self.status = newStatus }
        }

        rtspClient.onVideoConfigured = { [weak self] codec, parameterSets in
            guard let self else { return }
            #if DEBUG
            print("[Player] Video configured: \(codec), \(parameterSets.count) param sets")
            #endif
            let decoderCodec: VideoDecoder.Codec = codec == .h264 ? .h264 : .h265
            self.decoder.configure(codec: decoderCodec, parameterSets: parameterSets)
        }

        rtspClient.onNALUnit = { [weak self] nalData, timestamp in
            self?.decoder.decode(nalUnit: nalData, timestamp: timestamp)
        }

        decoder.onDecodedFrame = { [weak self] sampleBuffer in
            guard let self else { return }
            DispatchQueue.main.async {
                let layer = self.displayView.displayLayer

                if layer.status == .failed {
                    layer.flush()
                }

                layer.enqueue(sampleBuffer)
            }
        }
    }
}
