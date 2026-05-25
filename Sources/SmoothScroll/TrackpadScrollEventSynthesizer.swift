import CoreGraphics
import Foundation

enum TrackpadScrollPhase: Int64 {
    case none = 0
    case began = 1
    case changed = 2
    case ended = 4
    case cancelled = 8
    case mayBegin = 128
}

enum TrackpadMomentumPhase: Int64 {
    case none = 0
    case began = 1
    case changed = 2
    case ended = 3
}

final class TrackpadScrollEventSynthesizer {
    // These private fields are what make the output look like trackpad scroll/gesture events.
    private enum RawField {
        static let eventType = CGEventField(rawValue: 55)!
        static let scrollDeltaAxis1 = CGEventField(rawValue: 11)!
        static let scrollDeltaAxis2 = CGEventField(rawValue: 12)!
        static let fixedPointDeltaAxis1 = CGEventField(rawValue: 93)!
        static let fixedPointDeltaAxis2 = CGEventField(rawValue: 94)!
        static let pointDeltaAxis1 = CGEventField(rawValue: 96)!
        static let pointDeltaAxis2 = CGEventField(rawValue: 97)!
        static let scrollPhase = CGEventField(rawValue: 99)!
        static let gestureSubtype = CGEventField(rawValue: 110)!
        static let gestureDeltaX = CGEventField(rawValue: 116)!
        static let gestureDeltaY = CGEventField(rawValue: 119)!
        static let momentumPhase = CGEventField(rawValue: 123)!
        static let gesturePhase = CGEventField(rawValue: 132)!
        static let directionInvertedFromDevice = CGEventField(rawValue: 137)!
    }

    private let eventTapLocation = CGEventTapLocation.cgSessionEventTap
    private var lineDeltaX = LineDeltaAccumulator()
    private var lineDeltaY = LineDeltaAccumulator()

    func resetLineAccumulator() {
        lineDeltaX.reset()
        lineDeltaY.reset()
    }

    func postScroll(
        deltaX: Int32,
        deltaY: Int32,
        scrollPhase: TrackpadScrollPhase,
        momentumPhase: TrackpadMomentumPhase,
        syntheticMarker: Int64,
        source: CGEventSource?
    ) {
        let needsPhaseEvent = scrollPhase == .ended ||
            scrollPhase == .cancelled ||
            scrollPhase == .mayBegin ||
            momentumPhase == .ended
        guard deltaX != 0 || deltaY != 0 || needsPhaseEvent else {
            return
        }

        postScrollWheelEvent(
            deltaX: deltaX,
            deltaY: deltaY,
            scrollPhase: scrollPhase,
            momentumPhase: momentumPhase,
            syntheticMarker: syntheticMarker,
            source: source
        )

        if scrollPhase != .none {
            postGestureEvent(
                deltaX: deltaX,
                deltaY: deltaY,
                phase: scrollPhase,
                syntheticMarker: syntheticMarker,
                source: source
            )
        }
    }

    private func postScrollWheelEvent(
        deltaX: Int32,
        deltaY: Int32,
        scrollPhase: TrackpadScrollPhase,
        momentumPhase: TrackpadMomentumPhase,
        syntheticMarker: Int64,
        source: CGEventSource?
    ) {
        let wheelCount: UInt32 = deltaX == 0 ? 1 : 2
        guard let event = CGEvent(
            scrollWheelEvent2Source: source,
            units: .pixel,
            wheelCount: wheelCount,
            wheel1: deltaY,
            wheel2: deltaX,
            wheel3: 0
        ) else {
            return
        }

        let lineDeltaY = lineDeltaY.nextDelta(for: Double(deltaY) / 10.0)
        let lineDeltaX = lineDeltaX.nextDelta(for: Double(deltaX) / 10.0)

        event.setIntegerValueField(RawField.eventType, value: 22)
        event.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        event.setIntegerValueField(RawField.directionInvertedFromDevice, value: 1)
        event.setIntegerValueField(RawField.scrollDeltaAxis1, value: lineDeltaY)
        event.setIntegerValueField(RawField.scrollDeltaAxis2, value: lineDeltaX)
        event.setIntegerValueField(RawField.fixedPointDeltaAxis1, value: fixedPointDelta(forLineDelta: lineDeltaY))
        event.setIntegerValueField(RawField.fixedPointDeltaAxis2, value: fixedPointDelta(forLineDelta: lineDeltaX))
        event.setIntegerValueField(RawField.pointDeltaAxis1, value: Int64(deltaY))
        event.setIntegerValueField(RawField.pointDeltaAxis2, value: Int64(deltaX))
        event.setIntegerValueField(RawField.scrollPhase, value: scrollPhase.rawValue)
        event.setIntegerValueField(RawField.momentumPhase, value: momentumPhase.rawValue)
        event.post(tap: eventTapLocation)
    }

    private func postGestureEvent(
        deltaX: Int32,
        deltaY: Int32,
        phase: TrackpadScrollPhase,
        syntheticMarker: Int64,
        source: CGEventSource?
    ) {
        guard let event = CGEvent(source: source) else {
            return
        }

        let gestureScale = 1.67
        event.setIntegerValueField(RawField.eventType, value: 29)
        event.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)
        event.setIntegerValueField(RawField.gestureSubtype, value: 6)
        event.setDoubleValueField(RawField.gestureDeltaX, value: Double(deltaX) * gestureScale)
        event.setDoubleValueField(RawField.gestureDeltaY, value: Double(deltaY) * gestureScale)
        event.setIntegerValueField(RawField.gesturePhase, value: phase.rawValue)
        event.post(tap: eventTapLocation)
    }

    private func fixedPointDelta(forLineDelta delta: Int64) -> Int64 {
        delta * 65_536
    }

    private struct LineDeltaAccumulator {
        private enum Bias {
            case towardPositive
            case towardNegative
        }

        private var residual = 0.0
        private var bias: Bias?

        mutating func reset() {
            residual = 0.0
            bias = nil
        }

        mutating func nextDelta(for value: Double) -> Int64 {
            guard value != 0 else {
                return 0
            }

            let valueBias: Bias = value > 0 ? .towardPositive : .towardNegative
            if bias != valueBias {
                residual = 0.0
                bias = valueBias
            }

            let preciseValue = value + residual
            let wholeValue = switch valueBias {
            case .towardPositive:
                ceil(preciseValue)
            case .towardNegative:
                floor(preciseValue)
            }
            residual = preciseValue - wholeValue
            return Int64(wholeValue)
        }
    }
}
