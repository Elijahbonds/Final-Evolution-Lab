import Foundation
import HealthKit
import CoreMotion

@Observable
@MainActor
class HealthKitService {
    var heartRate: Double = 0
    var activeCalories: Double = 0
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
    /// Asleep hours aggregated from **sleepAnalysis** samples in the last ~18h (prior night + morning).
    var sleepHoursLastNight: Double = 0

    private let store = HKHealthStore()
    private var refreshTask: Task<Void, Never>?

    private enum DefaultsKey {
        static let rhrBaselineEMA = "fel.hk.rhrBaselineEMA"
    }

    func requestAuthorization() async {
        guard isAvailable else { return }

        var readTypes: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.stepCount),
            HKQuantityType(.heartRateVariabilitySDNN),
        ]
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            readTypes.insert(sleep)
        }

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
        async let rhr = fetchLatestQuantity(type: HKQuantityType(.restingHeartRate), unit: HKUnit.count().unitDivided(by: .minute()))
        async let hrv = fetchLatestQuantity(type: HKQuantityType(.heartRateVariabilitySDNN), unit: .secondUnit(with: .milli))
        async let weekAvg = fetchWeeklyHRVAverage()
        async let sleepHrs = fetchSleepHoursRecentWindow()

        let (hrVal, calVal, rhrVal, hrvVal, weekAvgVal, sleepVal) = await (hr, cal, rhr, hrv, weekAvg, sleepHrs)
        heartRate = hrVal
        activeCalories = calVal
        restingHeartRate = rhrVal
        hrvValue = hrvVal
        weeklyHRVAverage = weekAvgVal
        sleepHoursLastNight = sleepVal
        lastSyncDate = Date()

        calculateNeuralReadiness()
        calculateTrend()
        calculateRecoveryEstimate()

        Task { [weak self] in
            guard let self else { return }
            do {
                try await SystemScanFirestoreSync.shared.syncLatestFromHealthKit(self)
            } catch {
#if DEBUG
                print("[SystemScanFirestoreSync] \(error.localizedDescription)")
#endif
            }
        }
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

    // MARK: - Vertical jump tracking (CoreMotion flight-time estimation)

    private let jumpMotionManager = CMMotionManager()
    private var jumpHandler: ((Double) -> Void)?
    private var freefallStartTimestamp: TimeInterval?

    /// Starts vertical-jump detection; `onJump` receives estimated height in inches.
    /// Uses the flight-time method (h = g·t²/8): airborne = total acceleration near 0g,
    /// landing = impact spike. Requires the phone on the athlete (pocket/waistband).
    func startJumpTracking(onJump: @escaping (Double) -> Void) {
        guard jumpMotionManager.isDeviceMotionAvailable else { return }
        jumpHandler = onJump
        freefallStartTimestamp = nil
        jumpMotionManager.deviceMotionUpdateInterval = 1.0 / 100.0
        jumpMotionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let g = motion.gravity, u = motion.userAcceleration
            let totalG = ((g.x + u.x) * (g.x + u.x)
                        + (g.y + u.y) * (g.y + u.y)
                        + (g.z + u.z) * (g.z + u.z)).squareRoot()
            let now = motion.timestamp
            if totalG < 0.35 {
                if self.freefallStartTimestamp == nil { self.freefallStartTimestamp = now }
            } else if totalG > 1.6, let start = self.freefallStartTimestamp {
                self.freefallStartTimestamp = nil
                let flight = now - start
                guard flight > 0.15, flight < 1.2 else { return }
                let meters = 9.81 * flight * flight / 8.0
                self.jumpHandler?(meters * 39.3701)
            }
        }
    }

    func stopJumpTracking() {
        jumpMotionManager.stopDeviceMotionUpdates()
        jumpHandler = nil
        freefallStartTimestamp = nil
    }

    private func calculateNeuralReadiness() {
        var score: Double = 50

        if restingHeartRate > 0 {
            let alpha = 0.12
            let prior = UserDefaults.standard.double(forKey: DefaultsKey.rhrBaselineEMA)
            let ema = prior > 0 ? prior * (1 - alpha) + restingHeartRate * alpha : restingHeartRate
            UserDefaults.standard.set(ema, forKey: DefaultsKey.rhrBaselineEMA)
        }

        let athleteRhrBaseline: Double = {
            let ema = UserDefaults.standard.double(forKey: DefaultsKey.rhrBaselineEMA)
            return ema > 0 ? ema : 60.0
        }()

        if hrvValue > 0 {
            let hrvNormalized = min(1.0, max(0, (hrvValue - 20) / 80.0))
            score = 30 + hrvNormalized * 50
        } else {
            score = score * 0.92 + 4
        }

        if restingHeartRate > 0 {
            let rhrDeviation = abs(restingHeartRate - athleteRhrBaseline)
            let rhrPenalty = min(20, rhrDeviation * 1.2)
            if restingHeartRate > athleteRhrBaseline + 5 {
                score -= rhrPenalty
            } else if restingHeartRate < athleteRhrBaseline - 2 {
                score += min(10, (athleteRhrBaseline - restingHeartRate) * 0.45)
            }
        }

        if activeCalories > 0 {
            let activityBonus = min(8, activeCalories / 65.0)
            score += activityBonus
        }

        if sleepHoursLastNight > 0, sleepHoursLastNight < 6.25, activeCalories > 320 {
            score -= min(16, (activeCalories / 500.0) * 12)
        }

        if weeklyHRVAverage > 0 && hrvValue > 0 {
            let deviation = (hrvValue - weeklyHRVAverage) / weeklyHRVAverage
            score += deviation * 12
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

    private func fetchSleepHoursRecentWindow() async -> Double {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }
        let end = Date()
        guard let start = Calendar.current.date(byAdding: .hour, value: -18, to: end) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: sleepType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)],
            limit: HKObjectQueryNoLimit
        )

        do {
            let results = try await descriptor.result(for: store)
            var asleepSeconds: TimeInterval = 0
            for sample in results {
                guard sample.valueIsAsleepForAvatarMapping else { continue }
                asleepSeconds += sample.endDate.timeIntervalSince(sample.startDate)
            }
            return asleepSeconds / 3600.0
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

nonisolated enum NeuralReadinessGrade: String, Sendable {
    case elite = "ELITE"
    case primed = "PRIMED"
    case ready = "READY"
    case recovering = "RECOVERING"
}

nonisolated struct ArcadePhysicsBuff: Sendable {
    let neuralDriveOverride: Double
    let speedMultiplier: Double
    let hangTimeBonus: Double
    let isRecoveryMode: Bool
}

private extension HKCategorySample {
    /// True for intervals that count as asleep (excludes inBed-only / awake).
    var valueIsAsleepForAvatarMapping: Bool {
        if #available(iOS 16.0, *) {
            guard let v = HKCategoryValueSleepAnalysis(rawValue: value) else { return false }
            switch v {
            case .asleepUnspecified, .asleep, .asleepCore, .asleepDeep, .asleepREM:
                return true
            default:
                return false
            }
        } else {
            return value == HKCategoryValueSleepAnalysis.asleep.rawValue
                || value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        }
    }
}

nonisolated enum HRVTrend: String, Sendable {
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
