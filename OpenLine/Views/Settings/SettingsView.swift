//
//  SettingsView.swift
//  OpenLine
//
//  Created by Andrew Shea on 8/8/25.
//
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: OpenLineViewModel
    @StateObject private var syncManager = SyncManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var showingDurationPicker = false
    @State private var showingProfileSetup = false
    @State private var defaultDurationLocal: Int = 0



    var body: some View {
        NavigationStack {
            List {
                profileSection
                defaultDurationSection
                friendsSection
                notificationsSection
                doNotDisturbSection
                syncSection
                legalSection
            }
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $showingDurationPicker) {
            DefaultDurationPickerView(
                selectedDuration: $defaultDurationLocal,
                isPresented: $showingDurationPicker
            )
        }
        .sheet(isPresented: $showingProfileSetup) {
            ProfileSetupView(isPresented: $showingProfileSetup)
        }
        .onAppear {
            defaultDurationLocal = viewModel.defaultStatusDuration
        }
        .onChange(of: defaultDurationLocal) { newValue in
            viewModel.defaultStatusDuration = newValue
        }
    }
    
    private var profileSection: some View {
        Section {
            if let profile = syncManager.currentUserProfile {
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.name)
                        .font(.headline)
                    Text(profile.phoneNumber)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let email = profile.email {
                        Text(email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button("Edit Profile") {
                    showingProfileSetup = true
                }
            } else {
                Button("Setup Profile") {
                    showingProfileSetup = true
                }
            }
        } header: {
            Text("Profile")
        } footer: {
            Text("Your profile information is used to help friends find and connect with you.")
        }
    }
    
    private var defaultDurationSection: some View {
        Section {
            Button(action: { showingDurationPicker = true }) {
                HStack {
                    Text("Default Status Duration")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(formatDuration(defaultDurationLocal))
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .id(defaultDurationLocal)
            }
        } footer: {
            Text("Set your preferred default duration for status updates")
                .foregroundColor(.secondary)
        }
    }
    
    private var friendsSection: some View {
        Section {
            NavigationLink("Manage Friends") {
                ManageFriendsView(viewModel: viewModel)
            }
        } footer: {
            Text("Add or remove friends and control who can see your status")
                .foregroundColor(.secondary)
        }
    }
    
    private var doNotDisturbSection: some View {
        Section {
            HStack {
                Text("Do Not Disturb Integration")
                Spacer()
                Text(viewModel.respectsDoNotDisturb ? "Enabled" : "Disabled")
                    .foregroundColor(.secondary)
            }
        } footer: {
            Text("Automatically respect iOS Focus modes and Do Not Disturb settings")
                .foregroundColor(.secondary)
        }
    }
    
    private var notificationsSection: some View {
        Section {
            HStack {
                Text("Push Notifications")
                Spacer()
                Text(notificationStatusText)
                    .foregroundColor(notificationStatusColor)
            }

            if !notificationManager.isAuthorized {
                Button("Enable Notifications") {
                    notificationManager.requestAuthorization { granted in
                        if !granted {
                            // User denied - they'll need to enable in Settings
                        }
                    }
                }
            }
        } footer: {
            Text("Notifications alert you when friends send requests or update their status.")
                .foregroundColor(.secondary)
        }
    }

    private var notificationStatusText: String {
        switch notificationManager.authorizationStatus {
        case .authorized:
            return "Enabled"
        case .denied:
            return "Disabled"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Ephemeral"
        case .notDetermined:
            return "Not Set"
        @unknown default:
            return "Unknown"
        }
    }

    private var notificationStatusColor: Color {
        switch notificationManager.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .secondary
        }
    }

    private var syncSection: some View {
        Section {
            HStack {
                Text("Local Sync Mode")
                Spacer()
                Text(syncManager.isConnected ? "Active" : "Offline")
                    .foregroundColor(syncManager.isConnected ? .green : .orange)
            }

            if let profile = syncManager.currentUserProfile {
                Toggle("Allow others to find me", isOn: Binding(
                    get: { profile.isDiscoverable },
                    set: { newValue in
                        var updatedProfile = profile
                        updatedProfile.isDiscoverable = newValue
                        syncManager.saveUserProfile(updatedProfile)
                    }
                ))
            }
        } footer: {
            Text("Currently running in local testing mode. Real-time sync with friends will be available when your CloudKit setup is complete.")
                .foregroundColor(.secondary)
        }
    }

    private var legalSection: some View {
        Section {
            NavigationLink("Privacy Policy") {
                PrivacyPolicyView()
            }

            NavigationLink("Terms of Service") {
                TermsOfServiceView()
            }
        } header: {
            Text("Legal")
        }
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else if minutes % 60 == 0 {
            let hours = minutes / 60
            return hours == 1 ? "1 hour" : "\(hours) hours"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)hr \(mins)m"
        }
    }
}

