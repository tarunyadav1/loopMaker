import SwiftUI

/// Premium license activation gate with Liquid Glass design
struct LicenseGateView: View {
    @StateObject private var licenseService = LicenseService.shared
    @State private var showActivation = false
    @State private var licenseKey = ""
    @State private var isActivating = false
    @State private var errorMessage: String?
    @State private var isHoveringBuy = false
    @State private var isHoveringActivate = false

    var body: some View {
        ZStack {
            // Background with subtle gradient
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .windowBackgroundColor).opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Centered card
            VStack(spacing: 0) {
                // App Icon
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .padding(.top, 36)
                    .padding(.bottom, 20)

                // Title
                VStack(spacing: 8) {
                    Text("LoopMaker Pro")
                        .font(DesignSystem.Typography.displayMedium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text("Activate your license to continue")
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(.bottom, 32)

                // Content
                if showActivation {
                    activationView
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    optionsView
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            }
            .frame(width: 380)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.extraLarge))
            .shadow(color: DesignSystem.Shadows.medium, radius: 30, y: 10)
        }
        .frame(minWidth: 700, minHeight: 550)
        .animation(DesignSystem.Animations.smooth, value: showActivation)
    }

    // MARK: - Options View

    private var optionsView: some View {
        VStack(spacing: 14) {
            // Activate License Button
            Button {
                withAnimation {
                    showActivation = true
                }
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.accentGradient)
                            .frame(width: 40, height: 40)

                        Image(systemName: "key.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    Text("Activate License")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .fill(
                            isHoveringActivate
                                ? DesignSystem.Colors.surfaceHover
                                : DesignSystem.Colors.surface
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .onHover { isHoveringActivate = $0 }
            .scaleEffect(isHoveringActivate ? 1.01 : 1.0)
            .animation(DesignSystem.Animations.quick, value: isHoveringActivate)

            // Buy License
            Button {
                NSWorkspace.shared.open(Constants.URLs.gumroadURL)
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.surface)
                            .frame(width: 40, height: 40)

                        Image(systemName: "cart")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    Text("Buy License")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .fill(
                            isHoveringBuy
                                ? DesignSystem.Colors.surfaceHover
                                : DesignSystem.Colors.surface
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .onHover { isHoveringBuy = $0 }
            .scaleEffect(isHoveringBuy ? 1.01 : 1.0)
            .animation(DesignSystem.Animations.quick, value: isHoveringBuy)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 36)
    }

    // MARK: - Activation View

    private var activationView: some View {
        VStack(spacing: 20) {
            // Back button
            HStack {
                Button {
                    withAnimation {
                        showActivation = false
                        errorMessage = nil
                        licenseKey = ""
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Back")
                            .font(DesignSystem.Typography.callout)
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                Spacer()
            }

            // License key input
            VStack(alignment: .leading, spacing: 10) {
                Text("LICENSE KEY")
                    .font(DesignSystem.Typography.sectionHeader)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .tracking(0.5)

                TextField("Enter your license key", text: $licenseKey)
                    .textFieldStyle(.plain)
                    .font(DesignSystem.Typography.mono)
                    .padding(14)
                    .background(DesignSystem.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                            .stroke(
                                errorMessage != nil
                                    ? DesignSystem.Colors.error
                                    : DesignSystem.Colors.border,
                                lineWidth: 1
                            )
                    )
                    .onSubmit { activate() }

                if let error = errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 12))
                        Text(error)
                            .font(DesignSystem.Typography.caption)
                    }
                    .foregroundColor(DesignSystem.Colors.error)
                }
            }

            // Activate button
            Button {
                activate()
            } label: {
                HStack(spacing: 10) {
                    if isActivating {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    }
                    Text(isActivating ? "Activating..." : "Activate License")
                        .font(DesignSystem.Typography.bodySemibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .foregroundColor(.white)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                        .fill(DesignSystem.Colors.accentGradient)
                )
            }
            .buttonStyle(.plain)
            .disabled(licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isActivating)
            .opacity(licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 36)
    }

    // MARK: - Actions

    private func activate() {
        let key = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }

        isActivating = true
        errorMessage = nil

        Task {
            do {
                try await licenseService.activate(licenseKey: key)
                await MainActor.run {
                    isActivating = false
                }
            } catch {
                await MainActor.run {
                    isActivating = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    LicenseGateView()
}
