import Foundation

/// Service to communicate with Python backend for music generation
@MainActor
public final class PythonBackendService: ObservableObject {
    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL = URL(string: "http://localhost:8000")!) {
        self.baseURL = baseURL

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 900 // 15 minutes for longer ACE-Step generation
        self.session = URLSession(configuration: config)
    }

    // MARK: - Health Check

    /// Check if Python backend is running
    public func healthCheck() async throws -> Bool {
        let url = baseURL.appendingPathComponent("health")
        let (_, response) = try await session.data(from: url)
        return (response as? HTTPURLResponse)?.statusCode == 200
    }

    // MARK: - Generation

    /// Generate music using Python backend
    public func generate(
        request: GenerationRequest,
        progressHandler: @escaping (Double, String) -> Void
    ) async throws -> Track {
        let url = baseURL.appendingPathComponent("generate")

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "prompt": request.fullPrompt,
            "duration": request.duration.seconds,
            "model": request.model.rawValue
        ]

        if let seed = request.seed {
            body["seed"] = seed
        }

        // ACE-Step specific parameters
        if request.model.supportsLyrics {
            body["lyrics"] = request.effectiveLyrics ?? "[inst]"
            body["quality_mode"] = request.qualityMode.rawValue
            body["guidance_scale"] = request.guidanceScale
        }

        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        progressHandler(0.1, "Sending request to backend...")

        // Use streaming for progress updates
        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PythonBackendError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            // Try to parse error message from response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = json["detail"] as? String {
                throw PythonBackendError.generationFailed(detail)
            }
            throw PythonBackendError.generationFailed("Server returned status \(httpResponse.statusCode)")
        }

        progressHandler(0.9, "Processing audio...")

        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let audioBase64 = json["audio"] as? String,
              let audioData = Data(base64Encoded: audioBase64) else {
            throw PythonBackendError.invalidResponse
        }

        // Save audio to file
        let audioURL = try saveAudio(data: audioData)

        progressHandler(1.0, "Complete!")

        return Track(
            prompt: request.prompt,
            duration: request.duration,
            model: request.model,
            audioURL: audioURL,
            lyrics: request.lyrics
        )
    }

    // MARK: - Model Download

    /// Download a model via Python backend
    public func downloadModel(
        _ model: ModelType,
        progressHandler: @escaping (Double) -> Void
    ) async throws {
        let url = baseURL.appendingPathComponent("models/download")

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["model": model.rawValue]
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Stream download progress
        let (bytes, response) = try await session.bytes(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PythonBackendError.downloadFailed("Server returned error")
        }

        var lastProgress = 0.0
        for try await line in bytes.lines {
            if let data = line.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let progress = json["progress"] as? Double {
                    lastProgress = progress
                    progressHandler(progress)
                }
                if let status = json["status"] as? String, status == "error",
                   let error = json["error"] as? String {
                    throw PythonBackendError.downloadFailed(error)
                }
            }
        }

        if lastProgress < 1.0 {
            throw PythonBackendError.downloadFailed("Download incomplete")
        }
    }

    // MARK: - Model Status

    /// Model status info from backend
    public struct ModelStatus {
        public let downloaded: Bool
        public let loaded: Bool
        public let family: String
        public let sizeGB: Double
        public let maxDuration: Int
        public let supportsLyrics: Bool
    }

    /// Check which models are downloaded (simple bool for backwards compat)
    public func getModelStatus() async throws -> [ModelType: Bool] {
        let url = baseURL.appendingPathComponent("models/status")
        let (data, _) = try await session.data(from: url)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PythonBackendError.invalidResponse
        }

        var status: [ModelType: Bool] = [:]
        for model in ModelType.allCases {
            if let modelData = json[model.rawValue] as? [String: Any] {
                // New detailed format
                status[model] = modelData["downloaded"] as? Bool ?? false
            } else if let downloaded = json[model.rawValue] as? Bool {
                // Old simple format (backwards compat)
                status[model] = downloaded
            } else {
                status[model] = false
            }
        }
        return status
    }

    /// Get detailed model status
    public func getDetailedModelStatus() async throws -> [ModelType: ModelStatus] {
        let url = baseURL.appendingPathComponent("models/status")
        let (data, _) = try await session.data(from: url)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PythonBackendError.invalidResponse
        }

        var status: [ModelType: ModelStatus] = [:]
        for model in ModelType.allCases {
            if let modelData = json[model.rawValue] as? [String: Any] {
                status[model] = ModelStatus(
                    downloaded: modelData["downloaded"] as? Bool ?? false,
                    loaded: modelData["loaded"] as? Bool ?? false,
                    family: modelData["family"] as? String ?? "unknown",
                    sizeGB: modelData["size_gb"] as? Double ?? 0,
                    maxDuration: modelData["max_duration"] as? Int ?? 60,
                    supportsLyrics: modelData["supports_lyrics"] as? Bool ?? false
                )
            }
        }
        return status
    }

    // MARK: - Helpers

    private func saveAudio(data: Data) throws -> URL {
        let documentsURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let loopMakerURL = documentsURL.appendingPathComponent("LoopMaker/tracks", isDirectory: true)

        try FileManager.default.createDirectory(at: loopMakerURL, withIntermediateDirectories: true)

        let filename = "\(UUID().uuidString).wav"
        let fileURL = loopMakerURL.appendingPathComponent(filename)

        try data.write(to: fileURL)
        return fileURL
    }
}

// MARK: - Errors

public enum PythonBackendError: LocalizedError {
    case connectionFailed
    case generationFailed(String)
    case downloadFailed(String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "Could not connect to Python backend. Make sure it's running."
        case .generationFailed(let message):
            return "Generation failed: \(message)"
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        case .invalidResponse:
            return "Invalid response from backend"
        }
    }
}
