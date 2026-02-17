import SwiftUI

// MARK: - Player Bar

struct PlayerBar: View {
    let track: Track?
    @ObservedObject var audioPlayer: AudioPlayer
    var onPlayPause: () -> Void = {}
    var onSeek: (Double) -> Void = { _ in }
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?
    var onRepeatToggle: () -> Void = {}
    var onVolumeChange: (Float) -> Void = { _ in }

    @State private var isHoveringProgress = false
    @State private var hoverProgress: Double = 0
    @State private var isScrubbingProgress = false
    @State private var scrubProgress: Double?
    @State private var preMuteVolume: Float = 0.8

    var body: some View {
        if let track = track {
            VStack(spacing: 0) {
                // Progress bar at top edge
                progressBar
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, 6)
                    .padding(.bottom, 2)

                // Main layout: track info | controls | volume + time
                HStack(spacing: Spacing.md) {
                    // Left: Track info
                    trackInfo(track)
                        .frame(maxWidth: 320, alignment: .leading)

                    Spacer()

                    // Center: Playback controls + repeat
                    playbackControls

                    Spacer()

                    // Right: Volume + Time
                    HStack(spacing: Spacing.sm) {
                        volumeControl

                        // Time display
                        HStack(spacing: Spacing.sm) {
                            Text(currentTime)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(DesignSystem.Colors.textSecondary)

                            Text("/")
                                .font(.system(size: 10))
                                .foregroundStyle(DesignSystem.Colors.textMuted)

                            Text(duration)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(DesignSystem.Colors.textMuted)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .glassEffect(
                            .regular.tint(Color.primary.opacity(0.08)),
                            in: .capsule
                        )
                    }
                    .frame(maxWidth: 260, alignment: .trailing)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.md)
            }
            .frame(height: 82)
            .glassEffect(
                .regular.tint(Color.primary.opacity(0.03)),
                in: .rect(cornerRadius: 0)
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.primary.opacity(0.12))
                    .frame(height: 1)
            }
            .onAppear {
                if audioPlayer.volume > 0.001 {
                    preMuteVolume = audioPlayer.volume
                }
            }
            .onChange(of: audioPlayer.volume) {
                if audioPlayer.volume > 0.001 {
                    preMuteVolume = audioPlayer.volume
                }
            }
        }
    }

    // MARK: - Progress Bar (top edge, full width)

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.12))
                    .frame(height: 4)

                Capsule()
                    .fill(DesignSystem.Colors.accent)
                    .frame(width: geometry.size.width * effectiveProgress, height: 4)
                    .animation(
                        isScrubbingProgress ? nil : .linear(duration: 0.1),
                        value: effectiveProgress
                    )

                if isHoveringProgress || isScrubbingProgress {
                    Capsule()
                        .fill(DesignSystem.Colors.accent.opacity(0.18))
                        .frame(width: geometry.size.width * hoverProgress, height: 4)
                }

                Circle()
                    .fill(.white.opacity(0.95))
                    .frame(width: isScrubbingProgress ? 10 : 8, height: isScrubbingProgress ? 10 : 8)
                    .shadow(color: DesignSystem.Colors.accent.opacity(0.45), radius: 4, y: 0)
                    .offset(x: (geometry.size.width * effectiveProgress) - (isScrubbingProgress ? 5 : 4))
                    .opacity((isHoveringProgress || isScrubbingProgress) ? 1 : 0)
                    .animation(.easeInOut(duration: 0.12), value: isHoveringProgress)
                    .animation(.easeInOut(duration: 0.12), value: isScrubbingProgress)
            }
            .frame(height: 4)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .animation(.easeInOut(duration: 0.15), value: isHoveringProgress)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let newProgress = normalizedProgress(at: value.location.x, width: geometry.size.width)
                        isScrubbingProgress = true
                        scrubProgress = newProgress
                        hoverProgress = newProgress
                        onSeek(newProgress)
                    }
                    .onEnded { value in
                        let newProgress = normalizedProgress(at: value.location.x, width: geometry.size.width)
                        onSeek(newProgress)
                        scrubProgress = nil
                        isScrubbingProgress = false
                    }
            )
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        let newProgress = normalizedProgress(at: value.location.x, width: geometry.size.width)
                        hoverProgress = newProgress
                        scrubProgress = nil
                        isScrubbingProgress = false
                        onSeek(newProgress)
                    }
            )
            .onHover { hovering in
                isHoveringProgress = hovering
                if hovering {
                    hoverProgress = effectiveProgress
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Playback position")
            .accessibilityValue("\(currentTime) of \(duration)")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    onSeek(clampedProgress(effectiveProgress + 0.05))
                case .decrement:
                    onSeek(clampedProgress(effectiveProgress - 0.05))
                @unknown default:
                    break
                }
            }
        }
        .frame(height: 16)
    }

    // MARK: - Track Info

    private func trackInfo(_ track: Track) -> some View {
        HStack(spacing: Spacing.md) {
            // Album art placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(DesignSystem.Colors.accentGradient)
                    .frame(width: 44, height: 44)
                    .glassEffect(
                        .regular.tint(Theme.accentPrimary.opacity(0.14)),
                        in: .rect(cornerRadius: 10)
                    )

                Image(systemName: "waveform")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(track.displayTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)

                Text(track.prompt)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textMuted)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Playback Controls (centered)

    private var playbackControls: some View {
        GlassEffectContainer(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                // Repeat mode toggle (separate chip)
                PlayerControlButton(
                    icon: audioPlayer.repeatMode.icon,
                    size: .small,
                    isActive: audioPlayer.repeatMode != .off,
                    action: onRepeatToggle
                )

                // Transport controls (single centered capsule)
                HStack(spacing: Spacing.md) {
                    PlayerControlButton(
                        icon: "backward.fill",
                        size: .small,
                        action: { onPrevious?() }
                    )
                    .opacity(onPrevious != nil ? 1 : 0.3)
                    .disabled(onPrevious == nil)

                    PlayerControlButton(
                        icon: audioPlayer.isPlaying ? "pause.fill" : "play.fill",
                        size: .large,
                        isPrimary: true,
                        action: onPlayPause
                    )

                    PlayerControlButton(
                        icon: "forward.fill",
                        size: .small,
                        action: { onNext?() }
                    )
                    .opacity(onNext != nil ? 1 : 0.3)
                    .disabled(onNext == nil)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .glassEffect(
                    .regular.tint(Color.primary.opacity(0.08)),
                    in: .capsule
                )
            }
        }
    }

    // MARK: - Volume Control

    private var volumeControl: some View {
        HStack(spacing: 6) {
            // Speaker icon (click to mute/unmute)
            Button {
                if audioPlayer.volume > 0 {
                    onVolumeChange(0)
                } else {
                    onVolumeChange(preMuteVolume > 0.001 ? preMuteVolume : 0.8)
                }
            } label: {
                Image(systemName: volumeIcon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(audioPlayer.volume > 0 ? Theme.accentPrimary : Theme.textSecondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .glassEffect(
                .regular.tint(audioPlayer.volume > 0 ? Theme.accentPrimary.opacity(0.14) : Color.primary.opacity(0.08)).interactive(),
                in: .circle
            )

            // Volume slider
            Slider(value: Binding(
                get: { Double(audioPlayer.volume) },
                set: {
                    let newVolume = Float($0)
                    if newVolume > 0.001 {
                        preMuteVolume = newVolume
                    }
                    onVolumeChange(newVolume)
                }
            ), in: 0...1)
            .controlSize(.mini)
            .frame(width: 92)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .glassEffect(
            .regular.tint(Color.primary.opacity(0.08)),
            in: .capsule
        )
        .frame(width: 140, alignment: .trailing)
    }

    private func clampedProgress(_ value: Double) -> Double {
        max(0, min(1, value))
    }

    private func normalizedProgress(at x: CGFloat, width: CGFloat) -> Double {
        guard width > 0 else { return 0 }
        return clampedProgress(x / width)
    }

    private var effectiveProgress: Double {
        clampedProgress(scrubProgress ?? audioPlayer.progress)
    }

    private var volumeIcon: String {
        if audioPlayer.volume == 0 {
            return "speaker.slash.fill"
        } else if audioPlayer.volume < 0.33 {
            return "speaker.wave.1.fill"
        } else if audioPlayer.volume < 0.66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
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
    var isActive: Bool = false
    var action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            buttonLabel
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.94 : (isHovered ? 1.06 : 1))
        .glassEffect(
            controlGlassStyle,
            in: .circle
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private var buttonLabel: some View {
        Image(systemName: icon)
            .font(.system(size: size.iconSize, weight: .semibold))
            .foregroundStyle(
                isPrimary ? .white : (isActive ? Theme.accentPrimary : Theme.textSecondary)
            )
            .frame(width: size.buttonSize, height: size.buttonSize)
    }

    private var controlGlassStyle: Glass {
        if isPrimary {
            return .regular.tint(Theme.accentPrimary).interactive()
        }

        if isActive {
            return .regular.tint(Theme.accentPrimary.opacity(0.2)).interactive()
        }

        if isHovered {
            return .regular.tint(Color.primary.opacity(0.1)).interactive()
        }

        return .clear
    }
}

// MARK: - Preview

#if PREVIEWS
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
#endif
