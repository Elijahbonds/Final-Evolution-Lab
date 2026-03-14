import Foundation
import HealthKit

@Observable
@MainActor
class HealthKitService {
    var heartRate: Double = 0
    var activeCalories: Double = 0
    var stepCount: Double = 0
    var restingHeartRate: Double = 0
    var hrvValue: Double = 0
    var isAuthorized: Bool = false
    var isAvailable: Bool = HKHealthStore.isHealthDataAvailable()
    var neuralReadinessScore: Double = 50
    var neuralReadinessGrade: NeuralReadinessGrade = .ready
    var lastSyncDate: Date?
    var autoRefreshEnabled: Bool = false
    var dailyTrend: HRVTrend = .stable
    var weeklyHRVAverage: Double = 0
    var recoveryEstimateHours: Double = 0

    private let store = HKHealthStore()
    private var refreshTask: Task<Void, Never>?

    func requestAuthorization() async {
        guard isAvailable else { return }

        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.stepCount),
            HKQuantityType(.heartRateVariabilitySDNN)
        ]

        let shareTypes: Set<HKSampleType> = [
            HKQuantityType(.activeEnergyBurned)
        ]

        do {
            try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
            isAuthorized = true
            await fetchLatestData()
            startAutoRefresh()
        } catch {
            isAuthorized = false
        }
    }

    func fetchLatestData() async {
        guard isAuthorized else { return }
        async let hr = fetchLatestQuantity(type: HKQuantityType(.heartRate), unit: HKUnit.count().unitDivided(by: .minute()))
        async let cal = fetchLatestQuantity(type: HKQuantityType(.activeEnergyBurned), unit: .kilocalorie())
        async let steps = fetchLatestQuantity(type: HKQuantityType(.stepCount), unit: .count())
        async let rhr = fetchLatestQuantity(type: HKQuantityType(.restingHeartRate), unit: HKUnit.count().unitDivided(by: .minute()))
        async let hrv = fetchLatestQuantity(type: HKQuantityType(.heartRateVariabilitySDNN), unit: .secondUnit(with: .milli))
        async let weekAvg = fetchWeeklyHRVAverage()

        let (hrVal, calVal, stepVal, rhrVal, hrvVal, weekAvgVal) = await (hr, cal, steps, rhr, hrv, weekAvg)
        heartRate = hrVal
        activeCalories = calVal
        stepCount = stepVal
        restingHeartRate = rhrVal
        hrvValue = hrvVal
        weeklyHRVAverage = weekAvgVal
        lastSyncDate = Date()

        calculateNeuralReadiness()
        calculateTrend()
        calculateRecoveryEstimate()
    }

    func startAutoRefresh() {
        guard autoRefreshEnabled == false else { return }
        autoRefreshEnabled = true
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                guard !Task.isCancelled else { return }
                await fetchLatestData()
            }
        }
    }

    func stopAutoRefresh() {
        autoRefreshEnabled = false
        refreshTask?.cancel()
        refreshTask = nil
    }

    private func calculateNeuralReadiness() {
        var score: Double = 50

        if hrvValue > 0 {
            let hrvNormalized = min(1.0, max(0, (hrvValue - 20) / 80.0))
            score = 30 + hrvNormalized * 50
        }

        if restingHeartRate > 0 {
            let rhrBaseline: Double = 60
            let rhrDeviation = abs(restingHeartRate - rhrBaseline)
            let rhrPenalty = min(20, rhrDeviation * 1.5)
            if restingHeartRate > rhrBaseline + 5 {
                score -= rhrPenalty
            } else if restingHeartRate < rhrBaseline {
                score += min(10, (rhrBaseline - restingHeartRate) * 0.5)
            }
        }

        if activeCalories > 0 {
            let activityBonus = min(10, activeCalories / 50.0)
            score += activityBonus
        }

        if weeklyHRVAverage > 0 && hrvValue > 0 {
            let deviation = (hrvValue - weeklyHRVAverage) / weeklyHRVAverage
            score += deviation * 15
        }

        neuralReadinessScore = min(100, max(0, score))

        switch neuralReadinessScore {
        case 80...: neuralReadinessGrade = .elite
        case 60..<80: neuralReadinessGrade = .primed
        case 40..<60: neuralReadinessGrade = .ready
        default: neuralReadinessGrade = .recovering
        }
    }

    private func calculateTrend() {
        guard weeklyHRVAverage > 0, hrvValue > 0 else {
            dailyTrend = .stable
            return
        }
        let ratio = hrvValue / weeklyHRVAverage
        if ratio > 1.1 {
            dailyTrend = .improving
        } else if ratio < 0.9 {
            dailyTrend = .declining
        } else {
            dailyTrend = .stable
        }
    }

    private func calculateRecoveryEstimate() {
        if neuralReadinessGrade == .recovering {
            recoveryEstimateHours = max(4, (60 - neuralReadinessScore) * 0.5)
        } else if neuralReadinessGrade == .ready {
            recoveryEstimateHours = max(1, (70 - neuralReadinessScore) * 0.3)
        } else {
            recoveryEstimateHours = 0
        }
    }

    var arcadePhysicsBuff: ArcadePhysicsBuff {
        let speedMult: Double
        let hangBonus: Double

        switch neuralReadinessGrade {
        case .elite:
            speedMult = 1.15
            hangBonus = 0.3
        case .primed:
            speedMult = 1.05
            hangBonus = 0.15
        case .ready:
            speedMult = 1.0
            hangBonus = 0
        case .recovering:
            speedMult = 0.9
            hangBonus = -0.1
        }

        return ArcadePhysicsBuff(
            neuralDriveOverride: neuralReadinessScore,
            speedMultiplier: speedMult,
            hangTimeBonus: hangBonus,
            isRecoveryMode: neuralReadinessGrade == .recovering
        )
    }

    private func fetchLatestQuantity(type: HKQuantityType, unit: HKUnit) async -> Double {
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: Date()),
            end: Date(),
            options: .strictStartDate
        )

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 1
        )

        do {
            let results = try await descriptor.result(for: store)
            return results.first?.quantity.doubleValue(for: unit) ?? 0
        } catch {
            return 0
        }
    }

    private func fetchWeeklyHRVAverage() async -> Double {
        let calendar = Calendar.current
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) else { return 0 }

        let predicate = HKQuery.predicateForSamples(
            withStart: weekAgo,
            end: Date(),
            options: .strictStartDate
        )

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.heartRateVariabilitySDNN), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 50
        )

        do {
            let results = try await descriptor.result(for: store)
            guard !results.isEmpty else { return 0 }
            let total = results.reduce(0.0) { $0 + $1.quantity.doubleValue(for: .secondUnit(with: .milli)) }
            return total / Double(results.count)
        } catch {
            return 0
        }
    }
}

enum NeuralReadinessGrade: String, Sendable {
    case elite = "ELITE"
    case primed = "PRIMED"
    case ready = "READY"
    case recovering = "RECOVERING"
}

struct ArcadePhysicsBuff: Sendable {
    let neuralDriveOverride: Double
    let speedMultiplier: Double
    let hangTimeBonus: Double
    let isRecoveryMode: Bool
}

enum HRVTrend: String, Sendable {
    case improving = "IMPROVING"
    case stable = "STABLE"
    case declining = "DECLINING"

    var icon: String {
        switch self {
        case .improving: "arrow.up.right"
        case .stable: "arrow.right"
        case .declining: "arrow.down.right"
        }
    }

    var color: String {
        switch self {
        case .improving: "green"
        case .stable: "cyan"
        case .declining: "orange"
        }
    }
}
