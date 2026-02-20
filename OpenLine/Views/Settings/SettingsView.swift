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
            ScrollView {
                VStack(spacing: 20) {
                    // Profile section
                    profileSection
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // Settings section
                    settingsSection
                        .padding(.horizontal)

                    // Sync status section
                    syncSection
                        .padding(.horizontal)

                    // Legal section
                    legalSection
                        .padding(.horizontal)
                }
                .padding(.bottom, 20)
            }
            .background(Color(UIColor.systemBackground))
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

    // MARK: - Profile Section
    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Profile")
                .font(TurretTheme.headerFont(size: 13))
                .foregroundColor(.secondary)
                
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                if let profile = syncManager.currentUserProfile {
                    HStack(spacing: 12) {
                        // Profile avatar with blue accent
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.15))
                                .frame(width: 44, height: 44)

                            Text(String(profile.name.prefix(1)).uppercased())
                                .font(TurretTheme.statusFont(size: 18, weight: .bold))
                                .foregroundColor(.accentColor)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name)
                                .font(TurretTheme.statusFont(size: 15, weight: .medium))

                            Text(profile.phoneNumber)
                                .font(TurretTheme.captionFont(size: 13))
                                .foregroundColor(.secondary)

                            if let email = profile.email {
                                Text(email)
                                    .font(TurretTheme.captionFont(size: 12))
                                    .foregroundColor(Color(UIColor.tertiaryLabel))
                            }
                        }

                        Spacer()

                        Button(action: { showingProfileSetup = true }) {
                            Image(systemName: "pencil.circle")
                                .font(.system(size: 22))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(14)
                } else {
                    Button(action: { showingProfileSetup = true }) {
                        HStack {
                            Text("Setup Profile")
                                .font(TurretTheme.statusFont(size: 14, weight: .medium))
                                .foregroundColor(TurretTheme.ledAmber)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(14)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        }
    }

    // MARK: - Settings Section
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preferences")
                .font(TurretTheme.headerFont(size: 13))
                .foregroundColor(.secondary)
                
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                // Default duration
                Button(action: { showingDurationPicker = true }) {
                    settingsRow(
                        icon: "clock.fill",
                        iconColor: .accentColor,
                        title: "Default Duration",
                        value: formatDuration(defaultDurationLocal)
                    )
                }
                .buttonStyle(PlainButtonStyle())

                Divider()
                    .padding(.leading, 52)

                // Manage friends
                NavigationLink(destination: ManageFriendsView(viewModel: viewModel)) {
                    settingsRow(
                        icon: "person.2.fill",
                        iconColor: .accentColor,
                        title: "Manage Contacts",
                        value: "\(viewModel.friends.count)"
                    )
                }

                Divider()
                    .padding(.leading, 52)

                // Notifications
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(notificationStatusColor.opacity(0.15))
                            .frame(width: 32, height: 32)

                        Image(systemName: "bell.fill")
                            .font(.system(size: 14))
                            .foregroundColor(notificationStatusColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notifications")
                            .font(TurretTheme.statusFont(size: 14, weight: .medium))

                        Text(notificationStatusText)
                            .font(TurretTheme.captionFont(size: 12))
                            .foregroundColor(notificationStatusColor)
                    }

                    Spacer()

                    if notificationManager.authorizationStatus == .notDetermined {
                        Button(action: { notificationManager.requestAuthorization { _ in } }) {
                            Text("Enable")
                                .font(TurretTheme.statusFont(size: 12, weight: .medium))
                                .foregroundColor(TurretTheme.ledGreen)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(TurretTheme.ledGreen.opacity(0.15))
                                )
                        }
                    } else if notificationManager.authorizationStatus == .denied {
                        Button(action: {
                            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsUrl)
                            }
                        }) {
                            Text("Settings")
                                .font(TurretTheme.statusFont(size: 12, weight: .medium))
                                .foregroundColor(TurretTheme.ledAmber)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(TurretTheme.ledAmber.opacity(0.15))
                                )
                        }
                    }
                }
                .padding(14)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        }
    }

    private func settingsRow(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
            }

            Text(title)
                .font(TurretTheme.statusFont(size: 14, weight: .medium))

            Spacer()

            Text(value)
                .font(TurretTheme.captionFont(size: 13))
                .foregroundColor(.secondary)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(UIColor.tertiaryLabel))
        }
        .padding(14)
    }

    // MARK: - Sync Section
    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sync Status")
                .font(TurretTheme.headerFont(size: 13))
                .foregroundColor(.secondary)
                
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Sync icon
                    ZStack {
                        Circle()
                            .fill((syncManager.isConnected ? TurretTheme.ledGreen : TurretTheme.ledAmber).opacity(0.15))
                            .frame(width: 32, height: 32)

                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(syncManager.isConnected ? TurretTheme.ledGreen : TurretTheme.ledAmber)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("iCloud Sync")
                            .font(TurretTheme.statusFont(size: 14, weight: .medium))

                        Text(syncManager.isConnected ? "Connected" : "Offline")
                            .font(TurretTheme.captionFont(size: 12))
                            .foregroundColor(syncManager.isConnected ? TurretTheme.ledGreen : TurretTheme.ledAmber)
                    }

                    Spacer()
                }
                .padding(14)

                if let profile = syncManager.currentUserProfile {
                    Divider()
                        .padding(.leading, 52)

                    Toggle(isOn: Binding(
                        get: { profile.isDiscoverable },
                        set: { newValue in
                            var updatedProfile = profile
                            updatedProfile.isDiscoverable = newValue
                            syncManager.saveUserProfile(updatedProfile)
                        }
                    )) {
                        Text("Allow Discovery")
                            .font(TurretTheme.statusFont(size: 14, weight: .medium))
                    }
                    .tint(TurretTheme.ledGreen)
                    .padding(14)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        }
    }

    // MARK: - Legal Section
    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Legal")
                .font(TurretTheme.headerFont(size: 13))
                .foregroundColor(.secondary)
                
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                NavigationLink(destination: PrivacyPolicyView()) {
                    legalRow(title: "Privacy Policy")
                }

                Divider()
                    .padding(.leading, 14)

                NavigationLink(destination: TermsOfServiceView()) {
                    legalRow(title: "Terms of Service")
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        }
    }

    private func legalRow(title: String) -> some View {
        HStack {
            Text(title)
                .font(TurretTheme.statusFont(size: 14, weight: .medium))

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(UIColor.tertiaryLabel))
        }
        .padding(14)
    }

    // MARK: - Helpers
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
            return TurretTheme.ledGreen
        case .denied:
            return TurretTheme.ledRed
        case .notDetermined:
            return TurretTheme.ledAmber
        @unknown default:
            return .secondary
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
