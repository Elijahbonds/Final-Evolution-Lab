import Testing
import Foundation
@testable import FinalEvolutionLab

/// Unit coverage for the pure Lift-App-parity logic: segment-length math and
/// joint-deviation classification in ``ScanFormAnalysis``.
struct ScanFormAnalysisTests {

    // MARK: - Deviation classification

    @Test func classifyGoodWithinTolerance() {
        #expect(ScanFormAnalysis.classify(angle: 105, ideal: 105) == .good)
        #expect(ScanFormAnalysis.classify(angle: 105 + 11, ideal: 105) == .good)
        #expect(ScanFormAnalysis.classify(angle: 105 - 12, ideal: 105) == .good)
    }

    @Test func classifyWatchBand() {
        #expect(ScanFormAnalysis.classify(angle: 105 + 20, ideal: 105) == .watch)
        #expect(ScanFormAnalysis.classify(angle: 105 - 25, ideal: 105) == .watch)
    }

    @Test func classifyOffTarget() {
        #expect(ScanFormAnalysis.classify(angle: 105 + 40, ideal: 105) == .off)
        #expect(ScanFormAnalysis.classify(angle: 60, ideal: 105) == .off)
    }

    // MARK: - Segment math

    @Test func neutralConfigProducesHundredPercentProportions() {
        let result = makeResult(prq: 70, measured: true, config: .default)
        let audit = BiomechanicsAudit.fromScanResult(result)
        let analysis = ScanFormAnalysis.make(result: result, audit: audit)

        let torso = try! #require(analysis.segments.first { $0.id == "torso" })
        // heightScale 1.0 → 100% proportion, positive length.
        #expect(abs(torso.proportionPercent - 100.0) < 0.001)
        #expect(torso.lengthMeters > 0)
    }

    @Test func tallerLimbScaleIncreasesSegmentLength() {
        var tall = AvatarSkinConfig.default
        tall.limbLength = 1.2
        let baseResult = makeResult(prq: 70, measured: true, config: .default)
        let tallResult = makeResult(prq: 70, measured: true, config: tall)

        let baseAudit = BiomechanicsAudit.fromScanResult(baseResult)
        let tallAudit = BiomechanicsAudit.fromScanResult(tallResult)

        let baseThigh = ScanFormAnalysis.make(result: baseResult, audit: baseAudit).segments.first { $0.id == "thigh" }!
        let tallThigh = ScanFormAnalysis.make(result: tallResult, audit: tallAudit).segments.first { $0.id == "thigh" }!

        #expect(tallThigh.lengthMeters > baseThigh.lengthMeters)
    }

    @Test func measuredFlagTracksScanSource() {
        let demo = makeResult(prq: 70, measured: false, config: .default)
        let measured = makeResult(prq: 85, measured: true, config: .default)

        let demoAnalysis = ScanFormAnalysis.make(result: demo, audit: .fromScanResult(demo))
        let measuredAnalysis = ScanFormAnalysis.make(result: measured, audit: .fromScanResult(measured))

        #expect(demoAnalysis.isMeasured == false)
        #expect(measuredAnalysis.isMeasured == true)
    }

    @Test func lowScoreProducesOffTargetJoint() {
        // A low-PRQ measured scan should drive at least one joint off ideal.
        let result = makeResult(prq: 30, measured: true, config: .default)
        let audit = BiomechanicsAudit.fromScanResult(result)
        let analysis = ScanFormAnalysis.make(result: result, audit: audit)
        #expect(analysis.joints.contains { $0.verdict != .good })
    }

    // MARK: - Helpers

    private func makeResult(prq: Double, measured: Bool, config: AvatarSkinConfig) -> SystemScanResult {
        SystemScanResult(
            id: UUID().uuidString,
            date: Date(),
            prqScore: prq,
            verticalEstimateInches: 26,
            flightTimeSeconds: 0.52,
            movementGrade: "TEST",
            notes: [],
            recommendedTrack: "Flight",
            avatarConfig: config,
            source: measured ? .measured : .demoSynthetic,
            confidence01: measured ? 0.85 : 0.35
        )
    }
}
