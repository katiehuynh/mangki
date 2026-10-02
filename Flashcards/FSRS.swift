import Foundation

/// FSRS-6: Free Spaced Repetition Scheduler.
///
/// A faithful Swift port of the core scheduling math from
/// open-spaced-repetition/fsrs-rs (`model_v6.rs`, `inference_v6.rs`):
/// the 21 default parameters, the power forgetting curve, and the
/// stability/difficulty memory states that replace SM-2's ease factor.
///
/// Grades follow the FSRS convention: 1 = Again, 2 = Hard, 3 = Good, 4 = Easy.
///
/// Two documented simplifications versus Anki's full scheduler:
///  - a single 10-minute relearning step instead of configurable (re)learning steps
///  - a compact FSRS-style fuzz (same 2.5 / 7 / 20-day edges as the reference)
struct FSRS {
    /// Default FSRS-6 parameters (`FSRS6_DEFAULT_PARAMETERS` in fsrs-rs).
    /// [0..<4] initial stability · [4..<8] initial difficulty ·
    /// [8..<10] recall · [11..<17] forgetting (w[15] hard penalty, w[16] easy bonus) ·
    /// [17..<20] short-term · [20] decay.
    var weights: [Double] = [
        0.212, 1.2931, 2.3065, 8.2956,
        6.4133, 0.8334, 3.0194, 0.001,
        1.8722, 0.1666,
        0.796, 1.4835, 0.0614, 0.2629,
        1.6483, 0.6014, 1.8729,
        0.5425, 0.0912, 0.0658,
        0.1542,
    ]

    /// Target probability of recall at each review (Anki default: 0.9).
    var desiredRetention: Double = 0.9
    /// Longest interval ever assigned, in days (Anki default: 100 years).
    var maximumInterval: Double = 36500
    /// Delay after pressing Again (Anki's default relearning step: 10 minutes).
    var relearningDelay: TimeInterval = 10 * 60

    static let stabilityMin = 0.01
    static let stabilityMax = 36500.0
    static let difficultyMin = 1.0
    static let difficultyMax = 10.0

    // MARK: - Core math

    private var decay: Double { -weights[20] }
    private var factor: Double { pow(0.9, 1.0 / decay) - 1.0 }

    private func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
        min(high, max(low, value))
    }

    private func clampGrade(_ rating: Int) -> Int { min(4, max(1, rating)) }

    /// Probability of recall after `daysElapsed` days with memory stability `s`.
    /// R(t, S) = (1 + FACTOR · t / S)^DECAY
    func retrievability(daysElapsed: Double, stability: Double) -> Double {
        let s = max(stability, Self.stabilityMin)
        let t = max(0, daysElapsed).rounded()
        return pow(1.0 + factor * t / s, decay)
    }

    /// Days until recall probability decays to `desiredRetention`.
    func nextInterval(stability: Double) -> Double {
        let s = max(stability, Self.stabilityMin)
        let r = min(0.9999, max(0.0001, desiredRetention))
        return clamp(s / factor * (pow(r, 1.0 / decay) - 1.0), 0, Self.stabilityMax)
    }

    func initialStability(rating: Int) -> Double {
        clamp(weights[clampGrade(rating) - 1], Self.stabilityMin, Self.stabilityMax)
    }

    func initialDifficulty(rating: Int) -> Double {
        let g = Double(clampGrade(rating))
        return clamp(weights[4] - exp(weights[5] * (g - 1.0)) + 1.0,
                     Self.difficultyMin, Self.difficultyMax)
    }

    func nextDifficulty(_ difficulty: Double, rating: Int) -> Double {
        let g = Double(clampGrade(rating))
        let deltaD = -weights[6] * (g - 3.0)
        let newD = difficulty + ((10.0 - difficulty) / 9.0) * deltaD
        let reverted = weights[7] * initialDifficulty(rating: 4) + (1.0 - weights[7]) * newD
        return clamp(reverted, Self.difficultyMin, Self.difficultyMax)
    }

    func stabilityAfterRecall(stability: Double, difficulty: Double,
                              retrievability r: Double, rating: Int) -> Double {
        let g = clampGrade(rating)
        let hardPenalty = g == 2 ? weights[15] : 1.0
        let easyBonus = g == 4 ? weights[16] : 1.0
        let s = stability * (1.0 + exp(weights[8])
            * (11.0 - difficulty)
            * pow(stability, -weights[9])
            * (exp((1.0 - r) * weights[10]) - 1.0)
            * hardPenalty * easyBonus)
        return clamp(s, Self.stabilityMin, Self.stabilityMax)
    }

    func stabilityAfterFailure(stability s: Double, difficulty d: Double,
                               retrievability r: Double) -> Double {
        let w = weights
        let newS = w[11] * pow(d, -w[12]) * (pow(s + 1.0, w[13]) - 1.0) * exp((1.0 - r) * w[14])
        let cap = s / exp(w[17] * w[18])
        return clamp(min(newS, cap), Self.stabilityMin, Self.stabilityMax)
    }

    /// FSRS-style fuzz: spreads similar intervals so due dates don't clump.
    func fuzzed(days: Double) -> Double {
        var delta = 1.0
        for (edge, factor) in [(2.5, 0.15), (7.0, 0.1), (20.0, 0.05)] {
            delta += factor * (min(days, edge) / edge)
        }
        let low = max(1.0, (days - delta).rounded())
        let high = min(maximumInterval, (days + delta).rounded())
        guard high > low else { return min(maximumInterval, max(1.0, days.rounded())) }
        return Double.random(in: low...high)
    }

    // MARK: - Scheduling

    struct ReviewResult {
        /// Updated memory stability, in days.
        let stability: Double
        /// Updated memory difficulty, 1 (easy) – 10 (hard).
        let difficulty: Double
        /// Seconds until the next review.
        let interval: TimeInterval
        /// Predicted recall probability before this review (nil for new cards).
        let retrievability: Double?
    }

    /// Computes the outcome of grading a card. Pure — it mutates nothing,
    /// so it can also preview what each answer button would do.
    func reviewCard(stability: Double, difficulty: Double, reps: Int,
                    lastReview: Date?, rating: Int, now: Date = Date()) -> ReviewResult {
        let rating = clampGrade(rating)

        // New card: initialize the memory state from the grade.
        if reps == 0 {
            let s = initialStability(rating: rating)
            let d = initialDifficulty(rating: rating)
            if rating == 1 {
                return ReviewResult(stability: s, difficulty: d,
                                    interval: relearningDelay, retrievability: nil)
            }
            return ReviewResult(stability: s, difficulty: d,
                                interval: fuzzed(days: nextInterval(stability: s)) * 86400,
                                retrievability: nil)
        }

        let elapsed = lastReview.map { max(0, now.timeIntervalSince($0) / 86400) } ?? 0
        let deltaT = elapsed.rounded()
        let s0 = clamp(stability, Self.stabilityMin, Self.stabilityMax)
        let d0 = clamp(difficulty, Self.difficultyMin, Self.difficultyMax)
        let r = retrievability(daysElapsed: deltaT, stability: s0)

        let newS: Double
        if deltaT < 1 {
            // Same-day re-review: short-term stability update.
            let sinc = exp(weights[17] * (Double(rating) - 3.0 + weights[18])) * pow(s0, -weights[19])
            newS = clamp(s0 * (rating >= 2 ? max(1.0, sinc) : sinc),
                         Self.stabilityMin, Self.stabilityMax)
        } else if rating == 1 {
            newS = stabilityAfterFailure(stability: s0, difficulty: d0, retrievability: r)
        } else {
            newS = stabilityAfterRecall(stability: s0, difficulty: d0, retrievability: r, rating: rating)
        }
        let newD = nextDifficulty(d0, rating: rating)

        if rating == 1 {
            return ReviewResult(stability: newS, difficulty: newD,
                                interval: relearningDelay, retrievability: r)
        }
        let days = max(1.0, fuzzed(days: nextInterval(stability: newS)))
        return ReviewResult(stability: newS, difficulty: newD,
                            interval: days * 86400, retrievability: r)
    }

    // MARK: - Display

    /// Anki-style interval formatting: "10m", "3d", "2.5mo", "1.2y".
    static func formatInterval(_ interval: TimeInterval) -> String {
        let minutes = interval / 60
        if minutes < 1 { return "<1m" }
        if minutes < 60 { return "\(Int(minutes.rounded()))m" }
        let hours = minutes / 60
        if hours < 24 { return "\(Int(hours.rounded()))h" }
        let days = hours / 24
        if days < 30 { return "\(Int(days.rounded()))d" }
        let months = days / 30.44
        if months < 12 { return String(format: "%.1fmo", months) }
        return String(format: "%.1fy", months / 12)
    }
}
