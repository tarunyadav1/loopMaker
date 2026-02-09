import SwiftUI

// MARK: - Player Bar

struct PlayerBar: View {
    let track: Track?
    @ObservedObject var audioPlayer: AudioPlayer
    var onPlayPause: () -> Void = {}
    var onPrevious: () -> Void = {}
    var onNext: () -> Void = {}
    var onSeek: (Double) -> Void = { _ in }

    @State private var isHoveringProgress = false
    @State private var hoverProgress: Double = 0

    var body: some View {
        if let track = track {
            VStack(spacing: 0) {
                // Progress bar
                progressBar

                // Main content
                HStack(spacing: Spacing.lg) {
                    // Track info
                    trackInfo(track)

                    Spacer()

                    // Playback controls
                    playbackControls

                    Spacer()

                    // Secondary controls
                    secondaryControls
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
            }
            .frame(height: Spacing.playerBarHeight)
            .background(
                ZStack {
                    Theme.backgroundSecondary

                    // Top border
                    VStack {
                        Rectangle()
                            .fill(Theme.glassBorder)
                            .frame(height: 1)
                        Spacer()
                    }
                }
            )
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 2) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Rectangle()
                        .fill(Theme.backgroundTertiary)

                    // Progress fill
                    Rectangle()
                        .fill(Theme.accentGradient)
                        .frame(width: geometry.size.width * max(0, min(1, audioPlayer.progress)))
                        .animation(.linear(duration: 0.1), value: audioPlayer.progress)

                    // Hover indicator
                    if isHoveringProgress {
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: geometry.size.width * hoverProgress)
                    }
                }
                .frame(height: isHoveringProgress ? 6 : 3)
                .animation(.easeInOut(duration: 0.15), value: isHoveringProgress)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let newProgress = max(0, min(1, value.location.x / geometry.size.width))
                            hoverProgress = newProgress
                        }
                        .onEnded { value in
                            let newProgress = max(0, min(1, value.location.x / geometry.size.width))
                            onSeek(newProgress)
                        }
                )
                .onHover { hovering in
                    isHoveringProgress = hovering
                }
            }
            .frame(height: 6)

            // Time labels
            HStack {
                Text(currentTime)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary)

                Spacer()

                Text(duration)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, Spacing.sm)
        }
    }

    // MARK: - Track Info

    private func trackInfo(_ track: Track) -> some View {
        HStack(spacing: Spacing.md) {
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: Spacing.radiusSm)
                    .fill(Theme.accentGradient)
                    .frame(width: 48, height: 48)

                Image(systemName: "waveform")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
            }

            // Track details
            VStack(alignment: .leading, spacing: 2) {
                Text(track.displayTitle)
                    .font(Typography.bodyMedium)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                Text(track.prompt)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: 200, alignment: .leading)

            // Like button
            Button(action: {}) {
                Image(systemName: track.isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 16))
                    .foregroundStyle(track.isFavorite ? Theme.error : Theme.textSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        HStack(spacing: Spacing.lg) {
            // Shuffle
            PlayerControlButton(icon: "shuffle", size: .small) {}

            // Previous
            PlayerControlButton(icon: "backward.fill", size: .medium, action: onPrevious)

            // Play/Pause
            PlayerControlButton(
                icon: audioPlayer.isPlaying ? "pause.fill" : "play.fill",
                size: .large,
                isPrimary: true,
                action: onPlayPause
            )

            // Next
            PlayerControlButton(icon: "forward.fill", size: .medium, action: onNext)

            // Repeat
            PlayerControlButton(icon: "repeat", size: .small) {}
        }
    }

    // MARK: - Secondary Controls

    private var secondaryControls: some View {
        HStack(spacing: Spacing.md) {
            // Volume
            HStack(spacing: Spacing.sm) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)

                Slider(value: .constant(0.7))
                    .frame(width: 80)
                    .tint(Theme.accentPrimary)
            }

            // Share button
            Button(action: {}) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(.plain)

            // Queue button
            Button(action: {}) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var currentTime: String {
        audioPlayer.currentTimeFormatted
    }

    private var duration: String {
        audioPlayer.durationFormatted
    }
}

// MARK: - Player Control Button

struct PlayerControlButton: View {
    enum Size {
        case small, medium, large

        var iconSize: CGFloat {
            switch self {
            case .small: return 14
            case .medium: return 18
            case .large: return 22
            }
        }

        var buttonSize: CGFloat {
            switch self {
            case .small: return 32
            case .medium: return 36
            case .large: return 44
            }
        }
    }

    let icon: String
    var size: Size = .medium
    var isPrimary: Bool = false
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if isPrimary {
                    Circle()
                        .fill(Theme.accentPrimary)
                        .frame(width: size.buttonSize, height: size.buttonSize)
                }

                Image(systemName: icon)
                    .font(.system(size: size.iconSize, weight: .semibold))
                    .foregroundStyle(isPrimary ? .white : Theme.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.1 : 1)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()

        PlayerBar(
            track: Track(
                prompt: "Lo-fi beats with warm piano and soft drums",
                duration: .medium,
                model: .small,
                audioURL: URL(fileURLWithPath: "/tmp/test.wav"),
                title: "Sunset Vibes"
            ),
            audioPlayer: AudioPlayer()
        )
    }
    .background(Theme.background)
}
