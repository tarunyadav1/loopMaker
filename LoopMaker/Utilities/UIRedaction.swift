import Foundation

enum UIRedaction {
    private static let modelNamePatterns: [String] = [
        #"\bACE[-\s]?Step(?:[-\s]?v?1\.5(?:[-\s]?turbo)?)?\b"#,
        #"\bacestep(?:-v15-turbo)?\b"#,
        #"ACE-Step/acestep-v15-turbo"#,
    ]

    static func redactModelNames(in text: String) -> String {
        guard !text.isEmpty else { return text }

        var redacted = text
        for pattern in modelNamePatterns {
            redacted = redacted.replacingOccurrences(
                of: pattern,
                with: "music engine",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        return redacted
    }
}

