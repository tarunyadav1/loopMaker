import SwiftUI

// MARK: - Player Bar

struct PlayerBar: View {
    let track: Track?
    @ObservedObject var audioPlayer: AudioPlayer
    var onPlayPause: () -> Void = {}
    var onSeek: (Double) -> Void = { _ in }
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?

    @State private var isHoveringProgress = false
    @State private var hoverProgress: Double = 0

    var body: some View {
        if let track = track {
            VStack(spacing: 0) {
                // Progress bar at top edge
                progressBar

                // Main layout: track info | controls | time
                HStack(spacing: 0) {
                    // Left: Track info
                    trackInfo(track)
                        .frame(maxWidth: 260, alignment: .leading)

                    Spacer()

                    // Center: Playback controls
                    playbackControls

                    Spacer()

                    // Right: Time + progress text
                    HStack(spacing: Spacing.sm) {
                        Text(currentTime)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(DesignSystem.Colors.textSecondary)

                        // Mini progress indicator
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.primary.opacity(0.06))

                                Capsule()
                                    .fill(DesignSystem.Colors.accent)
                                    .frame(width: geometry.size.width * max(0, min(1, audioPlayer.progress)))
                            }
                        }
                        .frame(width: 60, height: 4)

                        Text(duration)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(DesignSystem.Colors.textMuted)
                    }
                    .frame(maxWidth: 220, alignment: .trailing)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
            }
            .frame(height: 68)
            .background(.regularMaterial)
        }
    }

    // MARK: - Progress Bar (top edge, full width)

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.primary.opacity(0.06))

                Rectangle()
                    .fill(DesignSystem.Colors.accent)
                    .frame(width: geometry.size.width * max(0, min(1, audioPlayer.progress)))
                    .animation(.linear(duration: 0.1), value: audioPlayer.progress)

                if isHoveringProgress {
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: geometry.size.width * hoverProgress)
                }
            }
            .frame(height: isHoveringProgress ? 5 : 3)
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
        .frame(height: 5)
    }

    // MARK: - Track Info

    private func trackInfo(_ track: Track) -> some View {
        HStack(spacing: Spacing.md) {
            // Album art placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(DesignSystem.Colors.accentGradient)
                    .frame(width: 42, height: 42)

                Image(systemName: "waveform")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(track.displayTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)

                Text(track.prompt)
                    .font(.system(size: 11))
                    .foregroundStyle(DesignSystem.Colors.textMuted)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Playback Controls (centered, Suno-style)

    private var playbackControls: some View {
        HStack(spacing: Spacing.lg) {
            // Previous
            PlayerControlButton(
                icon: "backward.fill",
                size: .small,
                action: { onPrevious?() }
            )
            .opacity(onPrevious != nil ? 1 : 0.3)
            .disabled(onPrevious == nil)

            // Play / Pause (primary, larger)
            PlayerControlButton(
                icon: audioPlayer.isPlaying ? "pause.fill" : "play.fill",
                size: .large,
                isPrimary: true,
                action: onPlayPause
            )

            // Next
            PlayerControlButton(
                icon: "forward.fill",
                size: .small,
                action: { onNext?() }
            )
            .opacity(onNext != nil ? 1 : 0.3)
            .disabled(onNext == nil)
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
                model: .acestep,
                audioURL: URL(fileURLWithPath: "/tmp/test.wav"),
                title: "Sunset Vibes"
            ),
            audioPlayer: AudioPlayer()
        )
    }
}
