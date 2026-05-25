import CoreVideo
import Foundation

final class DisplayLinkDriver: @unchecked Sendable {
    typealias Callback = (_ frameTime: TimeInterval, _ deltaTime: TimeInterval) -> Void

    private let callback: Callback
    private var displayLink: CVDisplayLink?
    private var isRunning = false
    private var lastFrameTime: TimeInterval?

    init?(callback: @escaping Callback) {
        self.callback = callback

        var displayLink: CVDisplayLink?
        let result = CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard result == kCVReturnSuccess, let displayLink else {
            return nil
        }

        self.displayLink = displayLink
        CVDisplayLinkSetOutputCallback(
            displayLink,
            { _, _, outputTime, _, _, userInfo in
                guard let userInfo else {
                    return kCVReturnSuccess
                }
                let driver = Unmanaged<DisplayLinkDriver>.fromOpaque(userInfo).takeUnretainedValue()
                driver.handle(outputTime: outputTime)
                return kCVReturnSuccess
            },
            Unmanaged.passUnretained(self).toOpaque()
        )
    }

    deinit {
        stop()
    }

    func start() {
        guard !isRunning, let displayLink else {
            return
        }
        isRunning = true
        lastFrameTime = nil
        CVDisplayLinkStart(displayLink)
    }

    func stop() {
        guard isRunning, let displayLink else {
            return
        }
        isRunning = false
        lastFrameTime = nil
        CVDisplayLinkStop(displayLink)
    }

    private func handle(outputTime: UnsafePointer<CVTimeStamp>) {
        let hostTime = outputTime.pointee.hostTime
        let frameTime = hostTime == 0
            ? ProcessInfo.processInfo.systemUptime
            : Double(hostTime) / CVGetHostClockFrequency()

        RunLoop.main.perform { [weak self] in
            guard let self, self.isRunning else {
                return
            }
            let deltaTime = self.lastFrameTime.map { frameTime - $0 } ?? (1.0 / 120.0)
            self.lastFrameTime = frameTime
            self.callback(frameTime, deltaTime)
        }
        CFRunLoopWakeUp(CFRunLoopGetMain())
    }
}
