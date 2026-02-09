import Foundation

enum Constants {
    enum URLs {
        static let helpURL = URL(string: "https://loopmaker.app/help")!
        static let privacyURL = URL(string: "https://loopmaker.app/privacy")!
        static let termsURL = URL(string: "https://loopmaker.app/terms")!
        static let gumroadURL = URL(string: "https://loopmaker.gumroad.com/l/pro")!
    }

    enum License {
        static let serverURL = "https://loopmaker-license.tarunyadav9761.workers.dev"
        static let offlineGracePeriod: TimeInterval = 7 * 24 * 60 * 60
        static let verificationInterval: TimeInterval = 24 * 60 * 60
    }

    enum Update {
        static let appcastURL = "https://loopmaker-updates.tarunyadav9761.workers.dev/appcast.xml"
        static let checkInterval: TimeInterval = 86400
    }
}
