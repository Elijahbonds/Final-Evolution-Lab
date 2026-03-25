import Foundation

/// High-frequency capture (120/240 fps): flight = (heelStrikeFrame − toeOffFrame) / nominalFPS.
nonisolated enum FELFlightTimeAnalysis {
    static func flightSeconds(toeOffFrame: Int, heelStrikeFrame: Int, nominalFPS: Double) -> Double? {
        guard nominalFPS > 0, heelStrikeFrame > toeOffFrame else { return nil }
        return Double(heelStrikeFrame - toeOffFrame) / nominalFPS
    }
}
