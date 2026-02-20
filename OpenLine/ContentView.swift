import SwiftUI
import WidgetKit

struct ContentView: View {
    @StateObject private var viewModel = OpenLineViewModel()
    @StateObject private var syncManager = SyncManager.shared
    @StateObject private var contactVerifier = ContactVerificationManager.shared
    @State private var selectedTab = 0
    @State private var tabResetTokens: [Int] = [0,0,0]
    @State private var showingOnboarding = false
    @State private var showingProfileSetup = false
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        Group {
            if showingOnboarding {
                OnboardingView(isPresented: $showingOnboarding)
            } else if showingProfileSetup {
                ProfileSetupView(isPresented: $showingProfileSetup)
            } else {
                TabView(selection: $selectedTab) {
                    FriendsView(viewModel: viewModel)
                        .id(tabResetTokens[0])
                        .tabItem {
                            Label("Friends", systemImage: "person.2.fill")
                        }
                        .tag(0)
                    
                    MyStatusView(viewModel: viewModel)
                        .id(tabResetTokens[1])
                        .tabItem {
                            Label("My Status", systemImage: "calendar.badge.clock")
                        }
                        .tag(1)
                    
                    SettingsView(viewModel: viewModel)
                        .id(tabResetTokens[2])
                        .tabItem {
                            Label("Settings", systemImage: "gearshape.fill")
                        }
                        .tag(2)
                }
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.showError = false
            }
        } message: {
            Text(viewModel.errorMessage ?? "An unexpected error occurred")
        }
        .onAppear {
            if viewModel.isFirstLaunch {
                showingOnboarding = true
            } else if syncManager.currentUserProfile?.name.isEmpty != false {
                showingProfileSetup = true
            }
            syncFromWidgetIfNeeded()
            viewModel.checkAndRefreshStatuses()
            viewModel.fetchFriendRequests()
            viewModel.syncToWidget()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            syncFromWidgetIfNeeded()
            viewModel.checkAndRefreshStatuses()
            viewModel.fetchFriendRequests()
            viewModel.syncToWidget()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SelectTabIndex"))) { notif in
            if let index = notif.object as? Int {
                selectedTab = index
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Sync from widget when app becomes active
                syncFromWidgetIfNeeded()
            } else if newPhase == .background {
                // Sync to widget when app goes to background
                viewModel.syncToWidget()
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    /// Sync status changes made from widget back to the app
    private func syncFromWidgetIfNeeded() {
        let widgetStatus = SharedDefaults.shared.currentStatus
        let widgetUntil = SharedDefaults.shared.statusUntil

        // Only sync if widget has a different status that was set more recently
        // Check if widget status differs and has a valid until time (meaning it was set by widget)
        if widgetStatus != viewModel.currentStatus,
           let until = widgetUntil,
           until > Date() {
            // Widget was updated - sync to app and CloudKit
            viewModel.updateCurrentStatus(
                status: widgetStatus,
                message: SharedDefaults.shared.statusMessage,
                until: until
            )
        }
    }
}

#Preview {
    ContentView()
}
