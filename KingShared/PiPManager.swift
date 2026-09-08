import AVFoundation
import AVKit
import CoreMedia
import CoreVideo
import Foundation
import UIKit

@MainActor
final class PiPManager: NSObject, ObservableObject, AVPictureInPictureControllerDelegate, AVPictureInPictureSampleBufferPlaybackDelegate {
    @Published private(set) var isRunning = false
    @Published private(set) var isSupported = false

    private let displayLayer = AVSampleBufferDisplayLayer()
    private var controller: AVPictureInPictureController?
    private var timer: Timer?
    private var frame = BattleFrame()
    private var settings = DisplaySettings()
    private var presentationTime = CMTime.zero
    private let width = 720
    private let height = 405

    override init() {
        super.init()
        isSupported = AVPictureInPictureController.isPictureInPictureSupported()
        displayLayer.videoGravity = .resizeAspect
        if isSupported {
            controller = AVPictureInPictureController(contentSource: AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: displayLayer, playbackDelegate: self))
            controller?.delegate = self
        }
    }

    func update(frame: BattleFrame, settings: DisplaySettings) {
        self.frame = frame
        self.settings = settings
    }

    func start() {
        guard let controller, isSupported, !controller.isPictureInPictureActive else { return }
        updateAudioSession(active: true)
        isRunning = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 15.0, repeats: true) { [weak self] _ in
            self?.pushFrame()
        }
        controller.startPictureInPicture()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        controller?.stopPictureInPicture()
        isRunning = false
        updateAudioSession(active: false)
    }

    private func updateAudioSession(active: Bool) {
        let session = AVAudioSession.sharedInstance()
        if active {
            try? session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
            try? session.setActive(true)
        } else {
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func pushFrame() {
        guard let buffer = makePixelBuffer() else { return }
        var format: CMVideoFormatDescription?
        guard CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: buffer, formatDescriptionOut: &format) == noErr,
              let format else { return }
        presentationTime = CMTimeAdd(presentationTime, CMTime(value: 1, timescale: 15))
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 15), presentationTimeStamp: presentationTime, decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        guard CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: buffer, formatDescription: format, sampleTiming: &timing, sampleBufferOut: &sample) == noErr,
              let sample else { return }
        displayLayer.enqueue(sample)
    }

    private func makePixelBuffer() -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true]
        guard CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &buffer) == kCVReturnSuccess,
              let buffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer), let context = CGContext(data: base, width: width, height: height, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { return nil }
        context.setFillColor(UIColor(red: 7/255, green: 16/255, blue: 22/255, alpha: 1).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let scale = min(CGFloat(width) / 2400, CGFloat(height) / 1080)
        let factor = CGFloat((1 + settings.mapSpacing / 100).clamped(to: 0.5...2))
        func point(_ x: Float, _ y: Float) -> CGPoint {
            CGPoint(x: ((CGFloat(x) - 170) * factor + 170 + CGFloat(settings.offsetX)) * scale,
                    y: ((CGFloat(y) - 170) * factor + 170 + CGFloat(settings.offsetY)) * scale)
        }
        func teamColor(_ blue: Bool) -> CGColor { (blue ? UIColor(red: 53/255, green: 163/255, blue: 255/255, alpha: settings.opacity) : UIColor(red: 255/255, green: 102/255, blue: 112/255, alpha: settings.opacity)).cgColor }
        if settings.minions {
            for unit in frame.minions { let p = point(unit.x, unit.y); context.setFillColor(teamColor(unit.blue)); context.fillEllipse(in: CGRect(x: p.x-3*scale, y: p.y-3*scale, width: 6*scale, height: 6*scale)) }
        }
        if settings.resources {
            for resource in frame.resources { let p = point(resource.x, resource.y); context.setFillColor(UIColor(red: 240/255, green: 188/255, blue: 85/255, alpha: settings.opacity).cgColor); context.fillEllipse(in: CGRect(x: p.x-5*scale, y: p.y-5*scale, width: 10*scale, height: 10*scale)); if resource.cooldown > 0 { drawText(context, "\(resource.cooldown)s", at: CGPoint(x: p.x, y: p.y-12*scale), size: 16*scale, color: .white) } }
        }
        let heroes = settings.hideOwnTeam ? frame.heroes.filter { !$0.ownTeam } : frame.heroes
        if settings.heroes {
            for hero in heroes {
                let p = point(hero.x, hero.y), radius = 20 * CGFloat(settings.avatarScale) * scale
                context.setFillColor(UIColor(red: 16/255, green: 29/255, blue: 39/255, alpha: settings.opacity).cgColor)
                context.fillEllipse(in: CGRect(x: p.x-radius, y: p.y-radius, width: radius*2, height: radius*2))
                context.setStrokeColor(teamColor(hero.blue)); context.setLineWidth(3*scale); context.strokeEllipse(in: CGRect(x: p.x-radius, y: p.y-radius, width: radius*2, height: radius*2))
                context.setFillColor(teamColor(hero.blue)); context.fill(CGRect(x: p.x-radius, y: p.y+radius, width: radius*2*CGFloat(hero.hp/100), height: 5*scale))
                drawText(context, String(hero.id.suffix(3)), at: p, size: max(10, 13*scale), color: .white)
            }
        }
        drawText(context, "王者共享 · HUD", at: CGPoint(x: width/2, y: height-18), size: 12, color: UIColor(white: 1, alpha: 0.7))
        return buffer
    }

    private func drawText(_ context: CGContext, _ value: String, at point: CGPoint, size: CGFloat, color: UIColor) {
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: size), .foregroundColor: color]
        let text = NSAttributedString(string: value, attributes: attributes)
        let bounds = text.size()
        text.draw(at: CGPoint(x: point.x - bounds.width/2, y: point.y - bounds.height/2))
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {}
    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange { CMTimeRange(start: .zero, duration: .positiveInfinity) }
    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool { false }
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {}
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion: @escaping () -> Void) { completion() }
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) { isRunning = true }
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) { isRunning = false; timer?.invalidate(); timer = nil; updateAudioSession(active: false) }
}
