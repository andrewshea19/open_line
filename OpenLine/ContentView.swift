import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = OpenLineViewModel()
    @StateObject private var syncManager = SyncManager.shared
    @StateObject private var contactVerifier = ContactVerificationManager.shared
    @SceneStorage("selectedTabIndex") private var selectedTab = 1
    @State private var tabResetTokens: [Int] = [0,0,0]
    @State private var showingOnboarding = false
    @State private var showingProfileSetup = false
    
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
                .tint(.primary)
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
            viewModel.checkAndRefreshStatuses()
            viewModel.fetchFriendRequests()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            viewModel.checkAndRefreshStatuses()
            viewModel.fetchFriendRequests()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SelectTabIndex"))) { notif in
            if let index = notif.object as? Int {
                selectedTab = index
            }
        }
    }
}

#Preview {
    ContentView()
}
