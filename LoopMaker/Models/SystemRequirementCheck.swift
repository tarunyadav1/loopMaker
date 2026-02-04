import Foundation

/// System requirement validation result
public struct SystemRequirementCheck: Sendable {
    public let availableRAM: Int
    public let requiredRAM: Int
    public let recommendedRAM: Int
    public let meetsMinimum: Bool
    public let meetsRecommended: Bool

    public init(
        availableRAM: Int,
        requiredRAM: Int,
        recommendedRAM: Int,
        meetsMinimum: Bool,
        meetsRecommended: Bool
    ) {
        self.availableRAM = availableRAM
        self.requiredRAM = requiredRAM
        self.recommendedRAM = recommendedRAM
        self.meetsMinimum = meetsMinimum
        self.meetsRecommended = meetsRecommended
    }

    /// Warning message if requirements not fully met
    public var warningMessage: String? {
        if !meetsMinimum {
            return "Your Mac has \(availableRAM)GB RAM but requires at least \(requiredRAM)GB."
        }
        if !meetsRecommended {
            return "Your Mac has \(availableRAM)GB RAM. \(recommendedRAM)GB is recommended for best performance."
        }
        return nil
    }

    /// Check system requirements for a model type
    public static func check(for model: ModelType) -> SystemRequirementCheck {
        let availableRAM = Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824)
        let required = model.minimumRAM
        let recommended = model.recommendedRAM

        return SystemRequirementCheck(
            availableRAM: availableRAM,
            requiredRAM: required,
            recommendedRAM: recommended,
            meetsMinimum: availableRAM >= required,
            meetsRecommended: availableRAM >= recommended
        )
    }
}
