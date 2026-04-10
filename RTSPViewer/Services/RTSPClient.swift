import Foundation
import Network
import CryptoKit
import CoreMedia

// MARK: - RTSP Client

/// Lightweight RTSP client using Network.framework.
/// Handles DESCRIBE/SETUP/PLAY, SDP parsing, digest auth,
/// and RTP-over-TCP (interleaved) depacketization for H.264/H.265.
final class RTSPClient: @unchecked Sendable {

    // MARK: - Types

    enum ConnectionState: Sendable {
        case disconnected, connecting, describing, setup, playing, error(String)
    }

    enum VideoCodec: Sendable {
        case h264, h265
    }

    struct VideoTrack {
        let codec: VideoCodec
        let payloadType: Int
        let controlPath: String
        let clockRate: Int
        let parameterSets: [Data]
    }

    // MARK: - Callbacks

    var onStateChange: (@Sendable (ConnectionState) -> Void)?
    /// Called once after SDP is parsed with codec info and parameter sets (SPS/PPS or VPS/SPS/PPS).
    var onVideoConfigured: (@Sendable (VideoCodec, [Data]) -> Void)?
    /// Called for each reassembled NAL unit ready for decoding.
    var onNALUnit: (@Sendable (Data, UInt32) -> Void)?

    // MARK: - Connection

    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.lotalink.lotaview.rtsp", qos: .userInitiated)
    private var receiveBuffer = Data()

    // MARK: - RTSP State

    private var state: ConnectionState = .disconnected
    private var cseq: Int = 0
    private var sessionID: String?
    private var contentBase: String?
    private var videoTrack: VideoTrack?
    private var pendingMethod: String?
    private var connectTime: Date?

    // MARK: - URL Components

    private var baseURL: String = ""
    private var host: String = ""
    private var port: UInt16 = 554
    private var username: String?
    private var password: String?

    // MARK: - Digest Auth

    private var digestRealm: String?
    private var digestNonce: String?
    private var hasAuth: Bool { digestRealm != nil && digestNonce != nil }
    private var authRetried: Bool = false

    // MARK: - RTP / NAL Assembly

    private var nalBuffer = Data()
    private var isAssemblingFU = false
    // H.264 FU-A reconstructed header byte
    private var fuNALHeader: UInt8 = 0
    // H.265 FU reconstructed header (2 bytes)
    private var fuH265Header = Data(count: 2)

    // In-band parameter sets (for cameras that don't include them in SDP)
    private var detectedSPS: Data?
    private var detectedPPS: Data?
    private var detectedVPS: Data?
    private var detectedCodec: VideoCodec?
    private var decoderConfigured = false

    // MARK: - Public

    func connect(url: String) {
        guard let components = URLComponents(string: url) else {
            updateState(.error("Invalid URL"))
            return
        }

        host = components.host ?? ""
        port = UInt16(components.port ?? 554)
        username = components.user
        password = components.password

        // Build URL without embedded credentials
        var clean = components
        clean.user = nil
        clean.password = nil
        baseURL = clean.string ?? url

        connectTime = Date()
        updateState(.connecting)

        let endpoint = NWEndpoint.hostPort(
            host: .init(host),
            port: .init(rawValue: port)!
        )

        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        tcp.connectionTimeout = 5
        let params = NWParameters(tls: nil, tcp: tcp)

        connection = NWConnection(to: endpoint, using: params)
        connection?.stateUpdateHandler = { [weak self] nwState in
            guard let self else { return }
            switch nwState {
            case .ready:
                self.updateState(.describing)
                self.sendDescribe(withAuth: false)
                self.startReceiving()
            case .failed(let err):
                self.updateState(.error("TCP: \(err.localizedDescription)"))
            case .cancelled:
                self.updateState(.disconnected)
            default:
                break
            }
        }
        connection?.start(queue: queue)
    }

    func disconnect() {
        queue.async { [weak self] in
            guard let self else { return }
            if case .playing = self.state {
                self.sendTeardown()
            }
            self.connection?.cancel()
            self.connection = nil
            self.reset()
        }
    }

    private func reset() {
        receiveBuffer.removeAll()
        sessionID = nil
        cseq = 0
        digestRealm = nil
        digestNonce = nil
        isAssemblingFU = false
        nalBuffer.removeAll()
        detectedSPS = nil
        detectedPPS = nil
        detectedVPS = nil
        decoderConfigured = false
        authRetried = false
        state = .disconnected
    }

    // MARK: - State

    private func updateState(_ newState: ConnectionState) {
        state = newState
        #if DEBUG
        if case .playing = newState, let start = connectTime {
            let elapsed = Date().timeIntervalSince(start)
            print("[RTSP] Playing in \(String(format: "%.1f", elapsed))s")
        }
        #endif
        onStateChange?(newState)
    }

    // MARK: - RTSP Commands

    private func nextCSeq() -> Int {
        cseq += 1
        return cseq
    }

    private func sendDescribe(withAuth: Bool) {
        pendingMethod = "DESCRIBE"
        var headers = "Accept: application/sdp\r\n"
        if withAuth { headers += authHeader(method: "DESCRIBE", uri: baseURL) }

        sendRequest(method: "DESCRIBE", url: baseURL, extraHeaders: headers)
    }

    private func sendSetup() {
        guard let track = videoTrack else { return }

        let trackURL: String
        if track.controlPath.hasPrefix("rtsp://") {
            trackURL = track.controlPath
        } else {
            let base = contentBase ?? baseURL
            let separator = base.hasSuffix("/") ? "" : "/"
            trackURL = base + separator + track.controlPath
        }

        pendingMethod = "SETUP"
        var headers = "Transport: RTP/AVP/TCP;unicast;interleaved=0-1\r\n"
        if hasAuth { headers += authHeader(method: "SETUP", uri: trackURL) }

        sendRequest(method: "SETUP", url: trackURL, extraHeaders: headers)
    }

    private func sendPlay() {
        pendingMethod = "PLAY"
        var headers = "Session: \(sessionID ?? "")\r\nRange: npt=0.000-\r\n"
        if hasAuth { headers += authHeader(method: "PLAY", uri: baseURL) }

        sendRequest(method: "PLAY", url: baseURL, extraHeaders: headers)
    }

    private func sendTeardown() {
        var headers = "Session: \(sessionID ?? "")\r\n"
        if hasAuth { headers += authHeader(method: "TEARDOWN", uri: baseURL) }
        sendRequest(method: "TEARDOWN", url: baseURL, extraHeaders: headers)
    }

    private func sendRequest(method: String, url: String, extraHeaders: String = "") {
        let seq = nextCSeq()
        var request = "\(method) \(url) RTSP/1.0\r\n"
        request += "CSeq: \(seq)\r\n"
        request += "User-Agent: LotaView/1.0\r\n"
        request += extraHeaders
        request += "\r\n"
        let data = Data(request.utf8)
        connection?.send(content: data, completion: .contentProcessed { error in
            #if DEBUG
            if let error {
                print("[RTSP] Send error: \(error)")
            }
            #endif
        })
    }

    // MARK: - Receive Loop

    private func startReceiving() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data {
                self.receiveBuffer.append(data)
                self.processBuffer()
            }
            if let error {
                self.updateState(.error("Recv: \(error.localizedDescription)"))
                return
            }
            if isComplete {
                self.updateState(.disconnected)
                return
            }
            self.startReceiving()
        }
    }

    // MARK: - Buffer Processing

    private func processBuffer() {
        while !receiveBuffer.isEmpty {
            if receiveBuffer[receiveBuffer.startIndex] == 0x24 {
                // Interleaved RTP/RTCP frame: $ | channel(1) | length(2) | data
                guard receiveBuffer.count >= 4 else { return }
                let offset = receiveBuffer.startIndex
                let channel = receiveBuffer[offset + 1]
                let length = Int(receiveBuffer[offset + 2]) << 8 | Int(receiveBuffer[offset + 3])
                guard receiveBuffer.count >= 4 + length else { return }

                if channel == 0 {
                    let rtpData = Data(receiveBuffer[(offset + 4)..<(offset + 4 + length)])
                    handleRTPPacket(rtpData)
                }
                receiveBuffer.removeFirst(4 + length)
            } else {
                // RTSP text response
                guard let range = receiveBuffer.range(of: Data("\r\n\r\n".utf8)) else { return }

                let headerData = Data(receiveBuffer[receiveBuffer.startIndex..<range.lowerBound])
                guard let headerStr = String(data: headerData, encoding: .utf8) else {
                    receiveBuffer.removeFirst(range.upperBound - receiveBuffer.startIndex)
                    continue
                }

                let contentLength = parseContentLength(headerStr)
                let headerSize = range.upperBound - receiveBuffer.startIndex
                let totalSize = headerSize + contentLength
                guard receiveBuffer.count >= totalSize else { return }

                let body: Data? = contentLength > 0
                    ? Data(receiveBuffer[range.upperBound..<(receiveBuffer.startIndex + totalSize)])
                    : nil

                receiveBuffer.removeFirst(totalSize)
                handleRTSPResponse(headerStr, body: body)
            }
        }
    }

    private func parseContentLength(_ header: String) -> Int {
        for line in header.split(separator: "\r\n") {
            let lower = line.lowercased()
            if lower.hasPrefix("content-length:") {
                let value = line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)
                return Int(value) ?? 0
            }
        }
        return 0
    }

    // MARK: - RTSP Response Handling

    private func handleRTSPResponse(_ header: String, body: Data?) {

        let lines = header.split(separator: "\r\n", omittingEmptySubsequences: false)
        guard let statusLine = lines.first else {

            return
        }

        // Parse status code: "RTSP/1.0 200 OK"
        let parts = statusLine.split(separator: " ", maxSplits: 2)
        guard parts.count >= 2, let statusCode = Int(parts[1]) else {

            return
        }
        // Parse headers into dict
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colonIdx = line.firstIndex(of: ":") else { continue }
            let key = String(line[line.startIndex..<colonIdx]).trimmingCharacters(in: .whitespaces).lowercased()
            let val = String(line[line.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
            headers[key] = val
        }

        let method = pendingMethod ?? ""

        // Handle 401 Unauthorized — extract digest challenge and retry ONCE
        if statusCode == 401 {
            if !authRetried, let authChallenge = headers["www-authenticate"], method == "DESCRIBE" {
                authRetried = true
                parseDigestChallenge(authChallenge)

                sendDescribe(withAuth: true)
            } else {

                updateState(.error("Authentication failed"))
            }
            return
        }

        guard statusCode == 200 else {
            updateState(.error("RTSP \(statusCode) on \(method)"))
            return
        }

        // Extract Content-Base for track URL resolution
        if let cb = headers["content-base"] {
            contentBase = cb
        }

        switch method {
        case "DESCRIBE":
            guard let body, let sdp = String(data: body, encoding: .utf8) else {
                updateState(.error("Empty SDP"))
                return
            }
            guard let track = parseSDP(sdp) else {
                updateState(.error("No video track in SDP"))
                return
            }
            videoTrack = track

            if !track.parameterSets.isEmpty {
                decoderConfigured = true
                detectedCodec = track.codec
                onVideoConfigured?(track.codec, track.parameterSets)
            }

            updateState(.setup)
            sendSetup()

        case "SETUP":
            // Parse Session header: "Session: 12345678;timeout=60"
            if let sessionHeader = headers["session"] {
                sessionID = String(sessionHeader.split(separator: ";").first ?? "")
            }
            sendPlay()

        case "PLAY":
            updateState(.playing)

        default:
            break
        }
    }

    // MARK: - SDP Parsing

    private func parseSDP(_ sdp: String) -> VideoTrack? {
        let lines = sdp.components(separatedBy: "\r\n")
            .flatMap { $0.components(separatedBy: "\n") }

        var inVideoSection = false
        var payloadType = -1
        var codec: VideoCodec?
        var controlPath: String?
        var clockRate = 90000
        var parameterSets: [Data] = []

        for line in lines {
            if line.hasPrefix("m=video") {
                inVideoSection = true
                // "m=video 0 RTP/AVP 96"
                let fields = line.split(separator: " ")
                if fields.count >= 4, let pt = Int(fields[3]) {
                    payloadType = pt
                }
                continue
            }
            if line.hasPrefix("m=") && !line.hasPrefix("m=video") {
                if inVideoSection { break }
                continue
            }

            guard inVideoSection else { continue }

            if line.hasPrefix("a=rtpmap:") {
                // "a=rtpmap:96 H264/90000"
                let value = String(line.dropFirst("a=rtpmap:".count))
                let parts = value.split(separator: " ")
                if parts.count >= 2 {
                    let codecParts = parts[1].split(separator: "/")
                    let codecName = String(codecParts[0]).uppercased()
                    if codecName == "H264" { codec = .h264 }
                    else if codecName == "H265" || codecName == "HEVC" { codec = .h265 }
                    if codecParts.count >= 2, let cr = Int(codecParts[1]) {
                        clockRate = cr
                    }
                }
            }

            if line.hasPrefix("a=fmtp:") {
                let value = String(line.dropFirst("a=fmtp:".count))
                // Skip payload type prefix
                let fmtp: String
                if let spaceIdx = value.firstIndex(of: " ") {
                    fmtp = String(value[value.index(after: spaceIdx)...])
                } else {
                    fmtp = value
                }

                parameterSets = parseParameterSets(fmtp: fmtp, codec: codec)
            }

            if line.hasPrefix("a=control:") {
                controlPath = String(line.dropFirst("a=control:".count))
            }
        }

        guard let codec, payloadType >= 0 else { return nil }

        return VideoTrack(
            codec: codec,
            payloadType: payloadType,
            controlPath: controlPath ?? "",
            clockRate: clockRate,
            parameterSets: parameterSets
        )
    }

    private func parseParameterSets(fmtp: String, codec: VideoCodec?) -> [Data] {
        // Parse key=value pairs separated by ; or ,
        let params = fmtp.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }
        var result: [Data] = []

        for param in params {
            let kv = param.split(separator: "=", maxSplits: 1)
            guard kv.count == 2 else { continue }
            let key = kv[0].trimmingCharacters(in: .whitespaces).lowercased()
            let value = String(kv[1].trimmingCharacters(in: .whitespaces))

            switch key {
            case "sprop-parameter-sets":
                // H.264: base64 SPS,PPS
                let sets = value.split(separator: ",")
                for set in sets {
                    if let data = Data(base64Encoded: String(set).trimmingCharacters(in: .whitespaces)) {
                        result.append(data)
                    }
                }

            case "sprop-vps":
                if let data = Data(base64Encoded: value) {
                    // VPS goes at index 0
                    if result.isEmpty { result.append(data) }
                    else { result.insert(data, at: 0) }
                }

            case "sprop-sps":
                if let data = Data(base64Encoded: value) {
                    // SPS goes at index 1 (after VPS)
                    if result.count < 2 { result.append(data) }
                    else { result.insert(data, at: 1) }
                }

            case "sprop-pps":
                if let data = Data(base64Encoded: value) {
                    result.append(data)
                }

            default:
                break
            }
        }
        return result
    }

    // MARK: - RTP Packet Handling

    private func handleRTPPacket(_ data: Data) {
        // RTP header: V(2) P(1) X(1) CC(4) | M(1) PT(7) | SeqNum(16) | Timestamp(32) | SSRC(32)
        guard data.count >= 12 else { return }

        let cc = Int(data[0] & 0x0F)
        let hasExtension = (data[0] & 0x10) != 0
        let timestamp = UInt32(data[4]) << 24 | UInt32(data[5]) << 16 | UInt32(data[6]) << 8 | UInt32(data[7])

        var payloadOffset = 12 + cc * 4

        // Skip RTP header extension if present
        if hasExtension {
            guard data.count >= payloadOffset + 4 else { return }
            let extLength = Int(data[payloadOffset + 2]) << 8 | Int(data[payloadOffset + 3])
            payloadOffset += 4 + extLength * 4
        }

        guard payloadOffset < data.count else { return }
        let payload = Data(data[payloadOffset...])

        guard let codec = videoTrack?.codec ?? detectedCodec else { return }

        switch codec {
        case .h264: depacketizeH264(payload, timestamp: timestamp)
        case .h265: depacketizeH265(payload, timestamp: timestamp)
        }
    }

    // MARK: - H.264 Depacketization (RFC 6184)

    private func depacketizeH264(_ payload: Data, timestamp: UInt32) {
        guard !payload.isEmpty else { return }

        let nalType = payload[0] & 0x1F

        switch nalType {
        case 1...23:
            // Single NAL unit
            checkInBandParamsH264(nalType: nalType, data: payload)
            if nalType != 7 && nalType != 8 {
                emitNAL(payload, timestamp: timestamp)
            }

        case 24:
            // STAP-A: aggregation packet
            var offset = 1
            while offset + 2 <= payload.count {
                let size = Int(payload[offset]) << 8 | Int(payload[offset + 1])
                offset += 2
                guard offset + size <= payload.count else { break }
                let nal = Data(payload[offset..<(offset + size)])
                let nt = nal[0] & 0x1F
                checkInBandParamsH264(nalType: nt, data: nal)
                if nt != 7 && nt != 8 {
                    emitNAL(nal, timestamp: timestamp)
                }
                offset += size
            }

        case 28:
            // FU-A: fragmentation unit
            guard payload.count >= 2 else { return }
            let fuHeader = payload[1]
            let isStart = (fuHeader & 0x80) != 0
            let isEnd = (fuHeader & 0x40) != 0
            let fuType = fuHeader & 0x1F

            if isStart {
                isAssemblingFU = true
                // Reconstruct NAL header: NRI from FU indicator + type from FU header
                fuNALHeader = (payload[0] & 0xE0) | fuType
                nalBuffer.removeAll(keepingCapacity: true)
                nalBuffer.append(fuNALHeader)
                nalBuffer.append(payload[2...])
            } else if isAssemblingFU {
                nalBuffer.append(payload[2...])
                if isEnd {
                    isAssemblingFU = false
                    let nt = fuType
                    checkInBandParamsH264(nalType: nt, data: nalBuffer)
                    if nt != 7 && nt != 8 {
                        emitNAL(nalBuffer, timestamp: timestamp)
                    }
                }
            }

        default:
            break
        }
    }

    // MARK: - H.265 Depacketization (RFC 7798)

    private func depacketizeH265(_ payload: Data, timestamp: UInt32) {
        guard payload.count >= 2 else { return }

        let nalType = (payload[0] >> 1) & 0x3F

        switch nalType {
        case 0...47:
            // Single NAL unit
            checkInBandParamsH265(nalType: nalType, data: payload)
            if nalType != 32 && nalType != 33 && nalType != 34 {
                emitNAL(payload, timestamp: timestamp)
            }

        case 48:
            // AP (Aggregation Packet)
            var offset = 2
            while offset + 2 <= payload.count {
                let size = Int(payload[offset]) << 8 | Int(payload[offset + 1])
                offset += 2
                guard offset + size <= payload.count else { break }
                let nal = Data(payload[offset..<(offset + size)])
                if nal.count >= 2 {
                    let nt = (nal[0] >> 1) & 0x3F
                    checkInBandParamsH265(nalType: nt, data: nal)
                    if nt != 32 && nt != 33 && nt != 34 {
                        emitNAL(nal, timestamp: timestamp)
                    }
                }
                offset += size
            }

        case 49:
            // FU (Fragmentation Unit)
            guard payload.count >= 3 else { return }
            let fuHeader = payload[2]
            let isStart = (fuHeader & 0x80) != 0
            let isEnd = (fuHeader & 0x40) != 0
            let fuType = fuHeader & 0x3F

            if isStart {
                isAssemblingFU = true
                // Reconstruct 2-byte NAL header with actual type
                fuH265Header[0] = (payload[0] & 0x81) | (fuType << 1)
                fuH265Header[1] = payload[1]
                nalBuffer.removeAll(keepingCapacity: true)
                nalBuffer.append(fuH265Header)
                nalBuffer.append(payload[3...])
            } else if isAssemblingFU {
                nalBuffer.append(payload[3...])
                if isEnd {
                    isAssemblingFU = false
                    checkInBandParamsH265(nalType: fuType, data: nalBuffer)
                    if fuType != 32 && fuType != 33 && fuType != 34 {
                        emitNAL(nalBuffer, timestamp: timestamp)
                    }
                }
            }

        default:
            break
        }
    }

    // MARK: - In-Band Parameter Set Detection

    private func checkInBandParamsH264(nalType: UInt8, data: Data) {
        switch nalType {
        case 7: detectedSPS = data; detectedCodec = .h264
        case 8: detectedPPS = data; detectedCodec = .h264
        default: return
        }
        tryConfigureFromInBand()
    }

    private func checkInBandParamsH265(nalType: UInt8, data: Data) {
        switch nalType {
        case 32: detectedVPS = data; detectedCodec = .h265
        case 33: detectedSPS = data; detectedCodec = .h265
        case 34: detectedPPS = data; detectedCodec = .h265
        default: return
        }
        tryConfigureFromInBand()
    }

    private func tryConfigureFromInBand() {
        guard !decoderConfigured else { return }
        guard let codec = detectedCodec else { return }

        switch codec {
        case .h264:
            guard let sps = detectedSPS, let pps = detectedPPS else { return }
            decoderConfigured = true
            onVideoConfigured?(codec, [sps, pps])

        case .h265:
            guard let vps = detectedVPS, let sps = detectedSPS, let pps = detectedPPS else { return }
            decoderConfigured = true
            onVideoConfigured?(codec, [vps, sps, pps])
        }
    }

    private func emitNAL(_ data: Data, timestamp: UInt32) {
        guard decoderConfigured else { return }
        onNALUnit?(data, timestamp)
    }

    // MARK: - Digest Authentication

    private func parseDigestChallenge(_ challenge: String) {
        // WWW-Authenticate: Digest realm="IP Camera", nonce="abc123"
        for part in challenge.components(separatedBy: ",") {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if let range = trimmed.range(of: "realm=\"") {
                let start = range.upperBound
                if let end = trimmed[start...].firstIndex(of: "\"") {
                    digestRealm = String(trimmed[start..<end])
                }
            }
            if let range = trimmed.range(of: "nonce=\"") {
                let start = range.upperBound
                if let end = trimmed[start...].firstIndex(of: "\"") {
                    digestNonce = String(trimmed[start..<end])
                }
            }
        }
    }

    private func authHeader(method: String, uri: String) -> String {
        guard let username, let password, let realm = digestRealm, let nonce = digestNonce else {
            return ""
        }
        let ha1 = md5String("\(username):\(realm):\(password)")
        let ha2 = md5String("\(method):\(uri)")
        let response = md5String("\(ha1):\(nonce):\(ha2)")

        return "Authorization: Digest username=\"\(username)\", realm=\"\(realm)\", nonce=\"\(nonce)\", uri=\"\(uri)\", response=\"\(response)\"\r\n"
    }

    private func md5String(_ input: String) -> String {
        let hash = Insecure.MD5.hash(data: Data(input.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
