import SwiftUI

/// Standalone setup view (can be used in a separate window if needed)
/// The main setup UI is in LoopMakerApp.swift as SetupOverlay
struct SetupView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        SetupProgressContent(
            state: appState.backendManager.state,
            isFirstLaunch: appState.backendManager.isFirstLaunch,
            onRetry: {
                Task {
                    await appState.retryBackendSetup()
                }
            }
        )
        .padding(40)
        .frame(minWidth: 500, minHeight: 400)
    }
}

#if PREVIEWS
#Preview("Setup View") {
    SetupView()
        .environmentObject(AppState())
}
#endif
