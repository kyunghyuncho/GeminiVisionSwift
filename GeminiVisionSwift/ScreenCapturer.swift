import Foundation
import ScreenCaptureKit
import AppKit
import CoreVideo
import CoreImage

@MainActor
final class ScreenCapturer {

    private let ciContext = CIContext()
    private var stream: SCStream?
    private var output: FrameCaptureOutput?   // <- strong reference!

    /// Capture one frame of the main display and return it as `NSImage`.
    func captureScreen() async throws -> NSImage {
        // 1. Enumerate shareable content
        let content = try await SCShareableContent.current
        guard let mainDisplay = content.displays.first else {
            throw CaptureError.noDisplay
        }
        
        // Get the running application for the current process.
        let runningApp = NSRunningApplication.current
        
        // Filter the full list of windows to find ones that belong to our app.
        let excludedWindows = content.windows.filter { window in
            // A window can be floating (like the screenshot UI), so check if it belongs to our app.
            return window.owningApplication?.processID == runningApp.processIdentifier
        }

        // 2. Build a filter – use *includingApplications* to avoid the empty‑array bug
        let filter = SCContentFilter(
            display: mainDisplay,
            excludingWindows: excludedWindows
        )

        // 3. Configure the stream
        let cfg = SCStreamConfiguration()
        cfg.width  = mainDisplay.width
        cfg.height = mainDisplay.height
        cfg.pixelFormat = kCVPixelFormatType_32BGRA        // supported
        cfg.queueDepth = 2
        cfg.capturesAudio = false

        // 4. Create and retain the stream
        let stream = SCStream(filter: filter, configuration: cfg, delegate: nil)
        self.stream = stream

        // 5. Wrap the delegate callback into async/await
        let surface = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<IOSurface, Error>) in
            let output = FrameCaptureOutput { surface in
                cont.resume(returning: surface)
            } didFail: { error in
                cont.resume(throwing: error)
            }
            self.output = output   // <- retain it for the lifetime of the capture

            do {
                try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .main)
                stream.startCapture { error in
                    if let error { cont.resume(throwing: error) }
                }
            } catch {
                cont.resume(throwing: error)
            }
        }

        // 6. Stop the stream and convert the IOSurface to NSImage
        try await stream.stopCapture()
        self.output = nil
        self.stream = nil

        let ciImage = CIImage(ioSurface: surface)
        guard let cg = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            throw CaptureError.cgImageCreation
        }
        return NSImage(cgImage: cg, size: .init(width: mainDisplay.width,
                                               height: mainDisplay.height))
    }

    // Simple local errors
    enum CaptureError: LocalizedError {
        case noDisplay, cgImageCreation
    }
}

/// Receives the first sample buffer and forwards it through the continuation.
final class FrameCaptureOutput: NSObject, SCStreamOutput {
    private let onSuccess: (IOSurface) -> Void
    private let onFailure: (Error) -> Void
    private var delivered = false

    init(onSuccess: @escaping (IOSurface) -> Void,
         didFail:    @escaping (Error) -> Void) {
        self.onSuccess = onSuccess
        self.onFailure = didFail
    }

    func stream(_ stream: SCStream,
                didOutputSampleBuffer sb: CMSampleBuffer,
                of type: SCStreamOutputType) {
        guard !delivered,
              type == .screen,
              sb.isValid,
              let buf = CMSampleBufferGetImageBuffer(sb),
              let surfaceRef = CVPixelBufferGetIOSurface(buf) else { return }

        delivered = true
        onSuccess(surfaceRef.takeUnretainedValue())
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        onFailure(error)
    }
}
