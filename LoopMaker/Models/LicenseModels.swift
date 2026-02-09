import Foundation

/// Represents the current license state of the app
enum LicenseState: Equatable {
    case unknown           // Not yet checked
    case unlicensed        // No license entered
    case validating        // Currently validating with server
    case valid(LicenseInfo) // License is valid
    case invalid(String)   // License validation failed with error message
    case expired           // License expired (if applicable)
    case offlineGrace      // Offline but within grace period

    var isValid: Bool {
        switch self {
        case .valid, .offlineGrace:
            return true
        default:
            return false
        }
    }

    var isPro: Bool {
        isValid
    }

    var displayStatus: String {
        switch self {
        case .unknown:
            return "Checking license..."
        case .unlicensed:
            return "Free Version"
        case .validating:
            return "Validating..."
        case .valid:
            return "Pro License Active"
        case .invalid(let message):
            return message
        case .expired:
            return "License Expired"
        case .offlineGrace:
            return "Pro (Offline Mode)"
        }
    }
}

/// Information about a valid license
struct LicenseInfo: Codable, Equatable {
    let email: String?
    let productName: String?
    let createdAt: String?
    let activatedAt: String
    let variants: String?

    enum CodingKeys: String, CodingKey {
        case email
        case productName = "product_name"
        case createdAt = "created_at"
        case activatedAt = "activated_at"
        case variants
    }
}

/// Response from the license server
struct LicenseResponse: Codable {
    let success: Bool
    let message: String?
    let error: String?
    let licenseInfo: LicenseInfo?
    let activatedAt: String?

    enum CodingKeys: String, CodingKey {
        case success
        case message
        case error
        case licenseInfo = "license_info"
        case activatedAt = "activated_at"
    }
}

/// Stored license data (persisted locally)
struct StoredLicense: Codable {
    let licenseKey: String
    let machineId: String
    let activatedAt: Date
    let lastVerified: Date
    let licenseInfo: LicenseInfo?

    /// Grace period for offline usage (7 days)
    static let offlineGracePeriod: TimeInterval = Constants.License.offlineGracePeriod

    /// How often to re-verify with server (1 day)
    static let verificationInterval: TimeInterval = Constants.License.verificationInterval

    var isWithinGracePeriod: Bool {
        Date().timeIntervalSince(lastVerified) < Self.offlineGracePeriod
    }

    var needsReVerification: Bool {
        Date().timeIntervalSince(lastVerified) > Self.verificationInterval
    }
}

/// Errors that can occur during license operations
enum LicenseError: LocalizedError {
    case networkError(Error)
    case serverError(String)
    case invalidLicense
    case alreadyActivated
    case wrongMachine
    case licenseRevoked
    case noMachineId

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let message):
            return message
        case .invalidLicense:
            return "Invalid license key"
        case .alreadyActivated:
            return "License is already activated on another device"
        case .wrongMachine:
            return "License is activated on a different device"
        case .licenseRevoked:
            return "License has been revoked"
        case .noMachineId:
            return "Could not identify this device"
        }
    }
}

/// Features available in Pro version
enum ProFeature: String, CaseIterable {
    case extendedDuration = "extended_duration"
    case prioritySupport = "priority_support"

    var displayName: String {
        switch self {
        case .extendedDuration: return "Extended Durations"
        case .prioritySupport: return "Priority Support"
        }
    }

    var description: String {
        switch self {
        case .extendedDuration: return "Generate tracks up to 120s and 240s"
        case .prioritySupport: return "Get priority support via email"
        }
    }
}
