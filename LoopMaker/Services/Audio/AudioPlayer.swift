import AVFoundation
import Combine
import os

/// Audio player service for playback of generated tracks
@MainActor
public final class AudioPlayer: ObservableObject {
    // MARK: - Published State

    @Published public var isPlaying = false
    @Published public var currentTime: TimeInterval = 0
    @Published public var duration: TimeInterval = 0
    @Published public var progress: Double = 0

    // MARK: - Formatted Time Strings

    public var currentTimeFormatted: String {
        formatTime(currentTime)
    }

    public var durationFormatted: String {
        formatTime(duration)
    }

    public var remainingTimeFormatted: String {
        formatTime(max(0, duration - currentTime))
    }

    // MARK: - Private Properties

    private var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?
    private var currentTrackURL: URL?
    private let logger = Logger(subsystem: "com.loopmaker.LoopMaker", category: "AudioPlayer")

    // MARK: - Initialization

    public init() {}

    // MARK: - Public API

    /// Load and play a track
    public func play(url: URL) {
        // If same track and already loaded, just resume
        if currentTrackURL == url, let player = audioPlayer {
            if !player.isPlaying {
                player.play()
            }
            isPlaying = true
            startDisplayLink()
            return
        }

        // Stop current playback
        stop()

        // Load new track
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()

            audioPlayer = player
            currentTrackURL = url
            duration = player.duration
            currentTime = 0
            progress = 0

            player.play()
            isPlaying = true

            startDisplayLink()

            logger.info("Playing: \(url.lastPathComponent), duration: \(player.duration)s")
        } catch {
            logger.error("Error loading audio: \(error.localizedDescription)")
            isPlaying = false
        }
    }

    /// Pause playback
    public func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopDisplayLink()
    }

    /// Toggle play/pause for current track
    public func togglePlayPause() {
        guard let player = audioPlayer else { return }

        if player.isPlaying {
            pause()
        } else {
            player.play()
            isPlaying = true
            startDisplayLink()
        }
    }

    /// Stop and reset
    public func stop() {
        stopDisplayLink()
        audioPlayer?.stop()
        audioPlayer = nil
        currentTrackURL = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        progress = 0
    }

    /// Seek to a position (0.0 to 1.0)
    public func seek(to position: Double) {
        guard let player = audioPlayer else { return }
        let clampedPosition = max(0, min(1, position))
        let newTime = clampedPosition * player.duration
        player.currentTime = newTime
        currentTime = newTime
        progress = clampedPosition
    }

    /// Set volume (0.0 to 1.0)
    public func setVolume(_ volume: Float) {
        audioPlayer?.volume = max(0, min(1, volume))
    }

    /// Check if a specific URL is currently loaded
    public func isCurrentTrack(_ url: URL) -> Bool {
        currentTrackURL == url
    }

    // MARK: - Progress Timer

    private func startDisplayLink() {
        stopDisplayLink()

        // Use a timer for smooth progress updates (30fps)
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateProgress()
            }
        }
    }

    private func stopDisplayLink() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func updateProgress() {
        guard let player = audioPlayer else { return }

        // Update current time and progress
        currentTime = player.currentTime
        if player.duration > 0 {
            progress = player.currentTime / player.duration
        }

        // Check if playback finished
        if !player.isPlaying && isPlaying {
            // Check if we reached the end
            if currentTime >= duration - 0.1 || progress >= 0.99 {
                // Finished playing
                isPlaying = false
                stopDisplayLink()

                // Reset to beginning for replay
                player.currentTime = 0
                currentTime = 0
                progress = 0

                logger.info("Playback finished")
            }
        }
    }

    // MARK: - Helpers

    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite && time >= 0 else { return "0:00" }

        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
