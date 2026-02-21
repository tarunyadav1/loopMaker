import Foundation
import IOKit
import Security

/// Service for managing license activation and validation
@MainActor
final class LicenseService: ObservableObject {
    // MARK: - Singleton
    static let shared = LicenseService()

    // MARK: - Published Properties
    @Published private(set) var licenseState: LicenseState = .unknown
    @Published private(set) var isValidating = false
    @Published private(set) var hasCompletedInitialCheck = false

    // MARK: - Configuration
    /// License server URL from Constants
    private var serverURL: String { Constants.License.serverURL }

    #if DEBUG
    /// Development bypass key for testing
    private let devBypassKey = "LOOPMAKER-DEV-2024"
    #endif

    // MARK: - Private Properties
    private let keychainService = "com.loopmaker.license"
    private let keychainAccount = "license_key"
    private let storedLicenseKey = "com.loopmaker.stored_license"

    // MARK: - Machine ID
    /// Get unique hardware identifier for this Mac
    var machineId: String? {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        guard let uuid = IORegistryEntryCreateCFProperty(
            service,
            kIOPlatformUUIDKey as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String else {
            return nil
        }

        return uuid
    }

    // MARK: - Initialization
    private init() {
        // Check for existing license on startup
        Task {
            await checkExistingLicense()
        }
    }

    // MARK: - Public Methods

    /// Activate a license key
    func activate(licenseKey: String) async throws {
        guard let machineId = machineId else {
            throw LicenseError.noMachineId
        }

        isValidating = true
        licenseState = .validating
        defer { isValidating = false }

        #if DEBUG
        // Development bypass for testing
        if licenseKey == devBypassKey {
            Log.app.info("Dev bypass key used - activating without server")
            let devLicense = StoredLicense(
                licenseKey: licenseKey,
                machineId: machineId,
                activatedAt: Date(),
                lastVerified: Date(),
                licenseInfo: LicenseInfo(
                    email: "dev@loopmaker.app",
                    productName: "LoopMaker Pro (Dev)",
                    createdAt: ISO8601DateFormatter().string(from: Date()),
                    activatedAt: ISO8601DateFormatter().string(from: Date()),
                    variants: nil
                )
            )
            try storeLicenseKey(licenseKey)
            storeLocalLicense(devLicense)
            licenseState = .valid(devLicense.licenseInfo!)
            NotificationCenter.default.post(name: .licenseActivated, object: nil)
            return
        }
        #endif

        let response = try await callServer(
            endpoint: "activate",
            licenseKey: licenseKey,
            machineId: machineId
        )

        if response.success {
            // Store license in Keychain
            try storeLicenseKey(licenseKey)

            // Store full license data
            let storedLicense = StoredLicense(
                licenseKey: licenseKey,
                machineId: machineId,
                activatedAt: Date(),
                lastVerified: Date(),
                licenseInfo: response.licenseInfo
            )
            storeLocalLicense(storedLicense)

            licenseState = .valid(response.licenseInfo ?? LicenseInfo(
                email: nil,
                productName: "LoopMaker Pro",
                createdAt: nil,
                activatedAt: response.activatedAt ?? ISO8601DateFormatter().string(from: Date()),
                variants: nil
            ))

            NotificationCenter.default.post(name: .licenseActivated, object: nil)
            Log.app.info("License activated successfully")
        } else {
            let error = mapServerError(response.error)
            licenseState = .invalid(response.message ?? error.errorDescription ?? "Activation failed")
            throw error
        }
    }

    /// Verify the current license
    func verify() async {
        guard let storedLicense = loadLocalLicense(),
              let machineId = machineId else {
            licenseState = .unlicensed
            return
        }

        // Enforce one-device binding locally as well.
        if storedLicense.machineId != machineId {
            clearLicense()
            licenseState = .unlicensed
            Log.app.warning("Local license machine binding mismatch - clearing stored license")
            return
        }

        // If we're offline but within grace period, allow
        do {
            isValidating = true
            defer { isValidating = false }

            let response = try await callServer(
                endpoint: "verify",
                licenseKey: storedLicense.licenseKey,
                machineId: machineId
            )

            if response.success {
                // Update last verified time
                let updatedLicense = StoredLicense(
                    licenseKey: storedLicense.licenseKey,
                    machineId: machineId,
                    activatedAt: storedLicense.activatedAt,
                    lastVerified: Date(),
                    licenseInfo: response.licenseInfo ?? storedLicense.licenseInfo
                )
                storeLocalLicense(updatedLicense)

                licenseState = .valid(response.licenseInfo ?? storedLicense.licenseInfo ?? LicenseInfo(
                    email: nil,
                    productName: "LoopMaker Pro",
                    createdAt: nil,
                    activatedAt: response.activatedAt ?? ISO8601DateFormatter().string(
                        from: storedLicense.activatedAt
                    ),
                    variants: nil
                ))
            } else {
                // Server says invalid - clear license
                clearLicense()
                licenseState = .invalid(response.message ?? "License verification failed")
            }
        } catch {
            // Network error - check grace period
            if storedLicense.isWithinGracePeriod {
                licenseState = .offlineGrace
            } else {
                licenseState = .invalid("Unable to verify license. Please connect to the internet.")
            }
        }
    }

    /// Deactivate the current license (for device transfer)
    func deactivate() async throws {
        guard let storedLicense = loadLocalLicense(),
              let machineId = machineId else {
            throw LicenseError.invalidLicense
        }

        isValidating = true
        defer { isValidating = false }

        let response = try await callServer(
            endpoint: "deactivate",
            licenseKey: storedLicense.licenseKey,
            machineId: machineId
        )

        if response.success {
            clearLicense()
            licenseState = .unlicensed
            NotificationCenter.default.post(name: .licenseDeactivated, object: nil)
            Log.app.info("License deactivated successfully")
        } else {
            throw mapServerError(response.error)
        }
    }

    /// Check if a specific Pro feature is available
    func isFeatureAvailable(_ feature: ProFeature) -> Bool {
        licenseState.isPro
    }

    /// Get the stored license key (masked for display)
    var maskedLicenseKey: String? {
        guard let key = loadLicenseKey() else { return nil }
        if key.count > 8 {
            let prefix = String(key.prefix(4))
            let suffix = String(key.suffix(4))
            return "\(prefix)--------\(suffix)"
        }
        return key
    }

    /// Get the stored license key (full, for deactivation)
    var currentLicenseKey: String? {
        loadLicenseKey()
    }

    // MARK: - Private Methods

    private func checkExistingLicense() async {
        defer { hasCompletedInitialCheck = true }

        guard let storedLicense = loadLocalLicense() else {
            licenseState = .unlicensed
            return
        }

        guard let machineId = machineId else {
            licenseState = .unlicensed
            return
        }

        if storedLicense.machineId != machineId {
            clearLicense()
            licenseState = .unlicensed
            Log.app.warning("Stored license belongs to a different machine - clearing local license")
            return
        }

        // Check if needs re-verification
        if storedLicense.needsReVerification {
            await verify()
        } else if storedLicense.isWithinGracePeriod {
            // Still valid from last check
            licenseState = .valid(storedLicense.licenseInfo ?? LicenseInfo(
                email: nil,
                productName: "LoopMaker Pro",
                createdAt: nil,
                activatedAt: ISO8601DateFormatter().string(from: storedLicense.activatedAt),
                variants: nil
            ))
        } else {
            // Grace period expired, need to verify
            await verify()
        }
    }

    private func callServer(
        endpoint: String,
        licenseKey: String,
        machineId: String
    ) async throws -> LicenseResponse {
        guard let url = URL(string: "\(serverURL)/\(endpoint)") else {
            throw LicenseError.serverError("Invalid server URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: String] = [
            "license_key": licenseKey,
            "machine_id": machineId
        ]
        request.httpBody = try JSONEncoder().encode(body)

        Log.app.info("License server request: \(endpoint)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LicenseError.networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode >= 500 {
            throw LicenseError.serverError("Server error. Please try again later.")
        }

        return try JSONDecoder().decode(LicenseResponse.self, from: data)
    }

    private func mapServerError(_ errorCode: String?) -> LicenseError {
        switch errorCode {
        case "invalid_license":
            return .invalidLicense
        case "already_activated":
            return .alreadyActivated
        case "wrong_machine":
            return .wrongMachine
        case "license_revoked":
            return .licenseRevoked
        default:
            return .serverError(errorCode ?? "Unknown error")
        }
    }

    // MARK: - Keychain Storage

    private func storeLicenseKey(_ key: String) throws {
        let data = key.data(using: .utf8)!

        // Try to update existing item first
        let searchQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        var status = SecItemUpdate(searchQuery as CFDictionary, updateAttributes as CFDictionary)

        if status == errSecItemNotFound {
            // No existing item, add a new one
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: keychainService,
                kSecAttrAccount as String: keychainAccount,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
            ]
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }

        if status != errSecSuccess {
            Log.app.error("Keychain store failed with OSStatus: \(status)")
            // Fall back to UserDefaults storage so activation isn't blocked
            UserDefaults.standard.set(key, forKey: "\(keychainService).fallback")
            Log.app.info("License key stored in UserDefaults fallback")
        }
    }

    private func loadLicenseKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }

        // Check UserDefaults fallback
        return UserDefaults.standard.string(forKey: "\(keychainService).fallback")
    }

    private func deleteLicenseKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
        UserDefaults.standard.removeObject(forKey: "\(keychainService).fallback")
    }

    // MARK: - Local Storage

    private func storeLocalLicense(_ license: StoredLicense) {
        if let data = try? JSONEncoder().encode(license) {
            UserDefaults.standard.set(data, forKey: storedLicenseKey)
        }
    }

    private func loadLocalLicense() -> StoredLicense? {
        guard let data = UserDefaults.standard.data(forKey: storedLicenseKey) else {
            return nil
        }
        return try? JSONDecoder().decode(StoredLicense.self, from: data)
    }

    private func clearLicense() {
        deleteLicenseKey()
        UserDefaults.standard.removeObject(forKey: storedLicenseKey)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let licenseActivated = Notification.Name("com.loopmaker.licenseActivated")
    static let licenseDeactivated = Notification.Name("com.loopmaker.licenseDeactivated")
}
