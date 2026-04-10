import Foundation
import VideoToolbox
import CoreMedia
import CoreVideo
import AVFoundation

/// Hardware-accelerated video decoder using VideoToolbox.
/// Accepts H.264/H.265 NAL units, outputs CMSampleBuffer for display.
final class VideoDecoder: @unchecked Sendable {

    // MARK: - Types

    enum Codec {
        case h264
        case h265
    }

    // MARK: - Callback

    /// Called on decode queue with decoded frame ready for AVSampleBufferDisplayLayer.
    var onDecodedFrame: ((CMSampleBuffer) -> Void)?

    // MARK: - State

    private let decodeQueue = DispatchQueue(label: "com.lotalink.lotaview.decode", qos: .userInitiated)
    private var decompressionSession: VTDecompressionSession?
    private var formatDescription: CMVideoFormatDescription?
    private var codec: Codec = .h264

    // MARK: - Configure

    func configure(codec: Codec, parameterSets: [Data]) {
        self.codec = codec
        decodeQueue.async { [weak self] in
            self?.createSession(codec: codec, parameterSets: parameterSets)
        }
    }

    func decode(nalUnit: Data, timestamp: UInt32) {
        decodeQueue.async { [weak self] in
            self?.decodeNAL(nalUnit, timestamp: timestamp)
        }
    }

    func invalidate() {
        decodeQueue.async { [weak self] in
            guard let self, let session = self.decompressionSession else { return }
            self.decompressionSession = nil
            self.formatDescription = nil
            // Invalidate without waiting — avoids deadlock/crash when session is mid-decode
            VTDecompressionSessionInvalidate(session)
        }
    }

    deinit {
        // Session cleanup is handled by invalidate() on decodeQueue.
        // Do NOT touch decompressionSession here — it may be mid-use on another thread.
        // If invalidate() wasn't called, the session will be cleaned up by the OS on dealloc.
    }

    // MARK: - Session Creation

    private func createSession(codec: Codec, parameterSets: [Data]) {
        // Teardown existing session
        if let session = decompressionSession {
            VTDecompressionSessionInvalidate(session)
            decompressionSession = nil
        }
        formatDescription = nil

        var formatDesc: CMVideoFormatDescription?

        switch codec {
        case .h264:
            guard parameterSets.count >= 2 else {
                #if DEBUG
                print("[Decoder] H.264 needs SPS+PPS, got \(parameterSets.count) sets")
                #endif
                return
            }
            let status = createH264FormatDescription(
                sps: parameterSets[0],
                pps: parameterSets[1],
                out: &formatDesc
            )
            guard status == noErr, formatDesc != nil else {
                #if DEBUG
                print("[Decoder] H.264 format description failed: \(status)")
                #endif
                return
            }

        case .h265:
            guard parameterSets.count >= 3 else {
                #if DEBUG
                print("[Decoder] H.265 needs VPS+SPS+PPS, got \(parameterSets.count) sets")
                #endif
                return
            }
            let status = createH265FormatDescription(
                vps: parameterSets[0],
                sps: parameterSets[1],
                pps: parameterSets[2],
                out: &formatDesc
            )
            guard status == noErr, formatDesc != nil else {
                #if DEBUG
                print("[Decoder] H.265 format description failed: \(status)")
                #endif
                return
            }
        }

        formatDescription = formatDesc

        // Create VTDecompressionSession with hardware acceleration
        let decoderSpec: [String: Any] = [
            kVTVideoDecoderSpecification_EnableHardwareAcceleratedVideoDecoder as String: true,
        ]
        let pixelBufferAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            kCVPixelBufferMetalCompatibilityKey as String: true,
        ]

        var session: VTDecompressionSession?
        let status = VTDecompressionSessionCreate(
            allocator: nil,
            formatDescription: formatDesc!,
            decoderSpecification: decoderSpec as CFDictionary,
            imageBufferAttributes: pixelBufferAttrs as CFDictionary,
            outputCallback: nil,
            decompressionSessionOut: &session
        )

        guard status == noErr, let session else {
            #if DEBUG
            print("[Decoder] Session create failed: \(status)")
            #endif
            return
        }

        // Prioritize realtime playback
        VTSessionSetProperty(session, key: kVTDecompressionPropertyKey_RealTime, value: kCFBooleanTrue)

        decompressionSession = session
        #if DEBUG
        print("[Decoder] Session created (\(codec == .h264 ? "H.264" : "H.265"))")
        #endif
    }

    // MARK: - Format Description Helpers

    private func createH264FormatDescription(
        sps: Data, pps: Data,
        out: inout CMVideoFormatDescription?
    ) -> OSStatus {
        sps.withUnsafeBytes { spsRaw in
            pps.withUnsafeBytes { ppsRaw in
                let spsPtr = spsRaw.baseAddress!.assumingMemoryBound(to: UInt8.self)
                let ppsPtr = ppsRaw.baseAddress!.assumingMemoryBound(to: UInt8.self)
                var ptrs = [spsPtr, ppsPtr]
                var sizes = [sps.count, pps.count]

                return CMVideoFormatDescriptionCreateFromH264ParameterSets(
                    allocator: nil,
                    parameterSetCount: 2,
                    parameterSetPointers: &ptrs,
                    parameterSetSizes: &sizes,
                    nalUnitHeaderLength: 4,
                    formatDescriptionOut: &out
                )
            }
        }
    }

    private func createH265FormatDescription(
        vps: Data, sps: Data, pps: Data,
        out: inout CMVideoFormatDescription?
    ) -> OSStatus {
        vps.withUnsafeBytes { vpsRaw in
            sps.withUnsafeBytes { spsRaw in
                pps.withUnsafeBytes { ppsRaw in
                    let vpsPtr = vpsRaw.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    let spsPtr = spsRaw.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    let ppsPtr = ppsRaw.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    var ptrs = [vpsPtr, spsPtr, ppsPtr]
                    var sizes = [vps.count, sps.count, pps.count]

                    return CMVideoFormatDescriptionCreateFromHEVCParameterSets(
                        allocator: nil,
                        parameterSetCount: 3,
                        parameterSetPointers: &ptrs,
                        parameterSetSizes: &sizes,
                        nalUnitHeaderLength: 4,
                        extensions: nil,
                        formatDescriptionOut: &out
                    )
                }
            }
        }
    }

    // MARK: - Decode

    private func decodeNAL(_ nalUnit: Data, timestamp: UInt32) {
        guard !nalUnit.isEmpty,
              let formatDescription,
              let session = decompressionSession else { return }

        // Skip parameter set NALs — they were used for format description
        switch codec {
        case .h264:
            let nalType = nalUnit[0] & 0x1F
            if nalType == 7 || nalType == 8 { return }
        case .h265:
            guard nalUnit.count >= 2 else { return }
            let nalType = (nalUnit[0] >> 1) & 0x3F
            if nalType == 32 || nalType == 33 || nalType == 34 { return }
        }

        // Build AVCC-format block buffer: 4-byte big-endian length + NAL data
        let dataLength = 4 + nalUnit.count

        var blockBuffer: CMBlockBuffer?
        var status = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: dataLength,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: dataLength,
            flags: kCMBlockBufferAssureMemoryNowFlag,
            blockBufferOut: &blockBuffer
        )
        guard status == noErr, let blockBuffer else { return }

        // Write 4-byte length prefix
        var nalLength = UInt32(nalUnit.count).bigEndian
        CMBlockBufferReplaceDataBytes(
            with: &nalLength,
            blockBuffer: blockBuffer,
            offsetIntoDestination: 0,
            dataLength: 4
        )

        // Write NAL payload
        nalUnit.withUnsafeBytes { rawBuf in
            CMBlockBufferReplaceDataBytes(
                with: rawBuf.baseAddress!,
                blockBuffer: blockBuffer,
                offsetIntoDestination: 4,
                dataLength: nalUnit.count
            )
        }

        // Create CMSampleBuffer
        let pts = CMTime(value: Int64(timestamp), timescale: 90000)
        var timingInfo = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: pts,
            decodeTimeStamp: .invalid
        )
        var sampleSize = dataLength

        var sampleBuffer: CMSampleBuffer?
        status = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            formatDescription: formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer
        )
        guard status == noErr, let sampleBuffer else { return }

        // Decode asynchronously — output comes via outputHandler closure
        var infoFlags = VTDecodeInfoFlags()
        VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer: sampleBuffer,
            flags: [._EnableAsynchronousDecompression],
            infoFlagsOut: &infoFlags
        ) { [weak self] decodeStatus, _, imageBuffer, presentationTS, duration in
            guard let self, decodeStatus == noErr, let imageBuffer else { return }
            self.emitDecodedFrame(imageBuffer: imageBuffer, pts: presentationTS, duration: duration)
        }
    }

    // MARK: - Decoded Frame Output

    private func emitDecodedFrame(imageBuffer: CVImageBuffer, pts: CMTime, duration: CMTime) {
        var formatDesc: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: nil,
            imageBuffer: imageBuffer,
            formatDescriptionOut: &formatDesc
        )
        guard let formatDesc else { return }

        var timing = CMSampleTimingInfo(
            duration: duration,
            presentationTimeStamp: pts,
            decodeTimeStamp: .invalid
        )

        var outputBuffer: CMSampleBuffer?
        let status = CMSampleBufferCreateForImageBuffer(
            allocator: nil,
            imageBuffer: imageBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDesc,
            sampleTiming: &timing,
            sampleBufferOut: &outputBuffer
        )

        if status == noErr, let outputBuffer {
            // Mark for immediate display — skip PTS-based scheduling
            // This ensures continuous rendering for live RTSP streams
            if let attachments = CMSampleBufferGetSampleAttachmentsArray(outputBuffer, createIfNecessary: true) as? [NSMutableDictionary],
               let dict = attachments.first {
                dict[kCMSampleAttachmentKey_DisplayImmediately] = true
            }
            onDecodedFrame?(outputBuffer)
        }
    }
}
