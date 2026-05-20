import Foundation

public struct ScrollPhysicsConfiguration: Equatable, Sendable {
    public var pixelsPerWheelStep: Double
    public var timeConstant: Double
    public var verticalMultiplier: Double
    public var horizontalMultiplier: Double
    public var acceleration: Double
    public var minimumVelocity: Double
    public var maximumVelocity: Double

    public init(
        pixelsPerWheelStep: Double = 72.0,
        timeConstant: Double = 0.18,
        verticalMultiplier: Double = 1.0,
        horizontalMultiplier: Double = 1.0,
        acceleration: Double = 0.0,
        minimumVelocity: Double = 4.0,
        maximumVelocity: Double = 12_000.0
    ) {
        self.pixelsPerWheelStep = pixelsPerWheelStep
        self.timeConstant = timeConstant
        self.verticalMultiplier = verticalMultiplier
        self.horizontalMultiplier = horizontalMultiplier
        self.acceleration = acceleration
        self.minimumVelocity = minimumVelocity
        self.maximumVelocity = maximumVelocity
    }

    public static let `default` = ScrollPhysicsConfiguration()
}

public struct ScrollFrame: Equatable, Sendable {
    public var pixelsX: Int32
    public var pixelsY: Int32

    public init(pixelsX: Int32, pixelsY: Int32) {
        self.pixelsX = pixelsX
        self.pixelsY = pixelsY
    }

    public var hasPixels: Bool {
        pixelsX != 0 || pixelsY != 0
    }
}

public struct ScrollPhysicsEngine: Sendable {
    public var configuration: ScrollPhysicsConfiguration

    private var velocityX: Double = 0
    private var velocityY: Double = 0
    private var residualX: Double = 0
    private var residualY: Double = 0

    public init(configuration: ScrollPhysicsConfiguration = .default) {
        self.configuration = configuration
    }

    public var isActive: Bool {
        abs(velocityX) > configuration.minimumVelocity ||
            abs(velocityY) > configuration.minimumVelocity ||
            abs(residualX) >= 1.0 ||
            abs(residualY) >= 1.0
    }

    public mutating func reset() {
        velocityX = 0
        velocityY = 0
        residualX = 0
        residualY = 0
    }

    public mutating func addWheelDelta(horizontalLines: Double, verticalLines: Double) {
        let timeConstant = max(configuration.timeConstant, 0.001)
        let acceleration = configuration.acceleration.clamped(to: 0.0 ... 2.0)
        let currentSpeed = max(abs(velocityX), abs(velocityY))
        let speedRatio = (currentSpeed / 2_500.0).clamped(to: 0.0 ... 1.0)
        let accelerationFactor = 1.0 + (acceleration * speedRatio)
        let horizontalPixels = horizontalLines * configuration.pixelsPerWheelStep *
            configuration.horizontalMultiplier * accelerationFactor
        let verticalPixels = verticalLines * configuration.pixelsPerWheelStep *
            configuration.verticalMultiplier * accelerationFactor

        velocityX += horizontalPixels / timeConstant
        velocityY += verticalPixels / timeConstant
        velocityX = velocityX.clamped(to: -configuration.maximumVelocity ... configuration.maximumVelocity)
        velocityY = velocityY.clamped(to: -configuration.maximumVelocity ... configuration.maximumVelocity)
    }

    public mutating func nextFrame(deltaTime rawDeltaTime: Double) -> ScrollFrame {
        let deltaTime = rawDeltaTime.clamped(to: 1.0 / 240.0 ... 1.0 / 15.0)
        let timeConstant = max(configuration.timeConstant, 0.001)
        let decay = exp(-deltaTime / timeConstant)

        residualX += velocityX * timeConstant * (1.0 - decay)
        residualY += velocityY * timeConstant * (1.0 - decay)

        velocityX *= decay
        velocityY *= decay

        if abs(velocityX) <= configuration.minimumVelocity {
            velocityX = 0
        }
        if abs(velocityY) <= configuration.minimumVelocity {
            velocityY = 0
        }

        return ScrollFrame(
            pixelsX: drainPixels(from: &residualX, flushing: velocityX == 0),
            pixelsY: drainPixels(from: &residualY, flushing: velocityY == 0)
        )
    }
}

private func drainPixels(from residual: inout Double, flushing: Bool) -> Int32 {
    let wholePixels: Double
    if flushing {
        wholePixels = residual.rounded(.toNearestOrAwayFromZero)
    } else {
        wholePixels = residual >= 0 ? floor(residual) : ceil(residual)
    }
    residual -= wholePixels
    return Int32(wholePixels)
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
