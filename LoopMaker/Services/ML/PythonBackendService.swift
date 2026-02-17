import Foundation

/// Service to communicate with Python backend for music generation
@MainActor
public final class PythonBackendService: ObservableObject {
    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL = URL(string: "http://127.0.0.1:8000")!) {
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

    /// Generate music using Python backend via WebSocket for real-time progress.
    /// Returns an array of tracks (one per batch variation).
    public func generate(
        request: GenerationRequest,
        progressHandler: @escaping (Double, String) -> Void
    ) async throws -> [Track] {
        // Build WebSocket URL from base HTTP URL
        let wsScheme = baseURL.scheme == "https" ? "wss" : "ws"
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw PythonBackendError.invalidResponse
        }
        components.scheme = wsScheme
        components.path += "/ws/generate"

        guard let wsURL = components.url else {
            throw PythonBackendError.invalidResponse
        }

        var wsRequest = URLRequest(url: wsURL)
        wsRequest.setValue(baseURL.absoluteString, forHTTPHeaderField: "Origin")
        let wsTask = session.webSocketTask(with: wsRequest)
        wsTask.resume()
        defer { wsTask.cancel(with: .normalClosure, reason: nil) }

        // Build and send generation request as JSON
        var body: [String: Any] = [
            "prompt": request.fullPrompt,
            "duration": request.duration.seconds,
            "model": request.model.rawValue,
        ]

        if let seed = request.seed {
            body["seed"] = seed
        }

        body["lyrics"] = request.effectiveLyrics
        body["quality_mode"] = request.qualityMode.rawValue
        body["guidance_scale"] = request.guidanceScale
        body["task_type"] = request.taskType.backendTaskType

        if request.batchSize > 1 {
            body["batch_size"] = request.batchSize
        }

        if let bpm = request.bpm {
            body["bpm"] = bpm
        }
        if let musicKey = request.musicKey {
            body["music_key"] = musicKey
        }
        if let timeSignature = request.timeSignature {
            body["time_signature"] = timeSignature
        }

        if request.taskType == .cover, let sourceURL = request.sourceAudioURL {
            body["source_audio_path"] = sourceURL.path
            body["ref_audio_strength"] = request.refAudioStrength
        }

        if request.taskType == .extend, let sourceURL = request.sourceAudioURL {
            body["source_audio_path"] = sourceURL.path
            if let start = request.repaintingStart {
                body["repainting_start"] = start
            }
            if let end = request.repaintingEnd {
                body["repainting_end"] = end
                body["duration"] = Int(end)
            }
        }

        let requestData = try JSONSerialization.data(withJSONObject: body)
        let requestString = String(data: requestData, encoding: .utf8)!
        try await wsTask.send(.string(requestString))

        progressHandler(0.01, "Connected to backend...")

        // Receive messages until complete or error
        while true {
            let message = try await wsTask.receive()

            guard let json = Self.parseWebSocketMessage(message) else {
                continue
            }

            guard let type = json["type"] as? String else {
                continue
            }

            switch type {
            case "progress":
                let progress = json["progress"] as? Double ?? 0
                let status = json["message"] as? String ?? "Processing..."
                progressHandler(progress, status)

            case "heartbeat":
                // Keep-alive, ignore
                break

            case "complete":
                // Support batch results (audio_paths array) with fallback to single audio_path
                let audioPaths: [String]
                let durations: [Double?]

                if let paths = json["audio_paths"] as? [String] {
                    audioPaths = paths
                    durations = (json["durations"] as? [Double])?.map { Optional($0) }
                        ?? Array(repeating: json["duration"] as? Double, count: paths.count)
                } else if let singlePath = json["audio_path"] as? String {
                    audioPaths = [singlePath]
                    durations = [json["duration"] as? Double]
                } else {
                    throw PythonBackendError.invalidResponse
                }

                // Parse seed from response (backend may return the actual seed used)
                let responseSeed: UInt64?
                if let seedVal = json["seed"] as? Int {
                    responseSeed = UInt64(seedVal)
                } else if let seedVal = json["seed"] as? UInt64 {
                    responseSeed = seedVal
                } else {
                    responseSeed = nil
                }
                let effectiveSeed = responseSeed ?? request.seed

                progressHandler(1.0, "Complete!")

                var tracks: [Track] = []
                for (index, audioPath) in audioPaths.enumerated() {
                    let fileURL = URL(fileURLWithPath: audioPath)
                    guard FileManager.default.fileExists(atPath: fileURL.path) else {
                        throw PythonBackendError.generationFailed("Audio file not found at \(audioPath)")
                    }

                    let variationSuffix = audioPaths.count > 1 ? " (v\(index + 1))" : ""
                    let track = Track(
                        prompt: request.prompt,
                        duration: request.duration,
                        model: request.model,
                        audioURL: fileURL,
                        title: audioPaths.count > 1 ? "\(request.prompt.prefix(25))\(variationSuffix)" : nil,
                        lyrics: request.lyrics,
                        taskType: request.taskType == .text2music ? nil : request.taskType.rawValue,
                        sourceAudioName: request.sourceAudioURL?.lastPathComponent,
                        sourceTrackID: request.sourceTrack?.id,
                        actualDurationSeconds: durations[index],
                        seed: effectiveSeed,
                        bpm: request.bpm,
                        musicKey: request.musicKey,
                        timeSignature: request.timeSignature,
                        guidanceScale: request.guidanceScale,
                        qualityMode: request.qualityMode.rawValue
                    )
                    tracks.append(track)
                }

                return tracks

            case "error":
                let detail = json["detail"] as? String ?? "Unknown error"
                throw PythonBackendError.generationFailed(detail)

            default:
                break
            }
        }
    }

    /// Parse a WebSocket message into a JSON dictionary
    private nonisolated static func parseWebSocketMessage(
        _ message: URLSessionWebSocketTask.Message
    ) -> [String: Any]? {
        let data: Data
        switch message {
        case .string(let text):
            guard let d = text.data(using: .utf8) else { return nil }
            data = d
        case .data(let d):
            data = d
        @unknown default:
            return nil
        }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    // MARK: - Model Download

    /// Download a model via Python backend
    public func downloadModel(
        _ model: ModelType,
        progressHandler: @escaping (Double, String?) -> Void
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
                    let message = json["message"] as? String
                    progressHandler(progress, message)
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
                    sizeGB: modelData["size_gb"] as? Double ?? 0,
                    maxDuration: modelData["max_duration"] as? Int ?? 240,
                    supportsLyrics: modelData["supports_lyrics"] as? Bool ?? true
                )
            }
        }
        return status
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
