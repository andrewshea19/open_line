//
//  PrivacyPolicyView.swift
//  OpenLine
//
//  Created by Andrew Shea on 1/27/26.
//
import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Privacy Policy")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Last updated: January 27, 2026")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                policySection(
                    title: "Information We Collect",
                    content: """
                    OpenLine collects the following information to provide our services:

                    • Name: Used to identify you to your friends
                    • Phone Number: Used as your primary identifier for friend connections
                    • Email Address (optional): Used as an alternative way for friends to find you
                    • Device Token: Used to send you push notifications about friend requests and status updates
                    • Status Information: Your availability status, messages, and schedules that you choose to share
                    """
                )

                policySection(
                    title: "How We Use Your Information",
                    content: """
                    We use your information to:

                    • Enable friends to find and connect with you
                    • Display your availability status to approved friends
                    • Send you notifications about friend requests and updates
                    • Sync your data across your devices via iCloud

                    We do not sell, rent, or share your personal information with third parties for marketing purposes.
                    """
                )

                policySection(
                    title: "Data Storage",
                    content: """
                    Your data is stored securely using Apple's CloudKit service:

                    • All data is encrypted in transit and at rest
                    • Data is stored in Apple's iCloud infrastructure
                    • You can delete your data at any time through the app or iCloud settings
                    • Local data is stored on your device and can be cleared by uninstalling the app
                    """
                )

                policySection(
                    title: "Data Sharing",
                    content: """
                    Your information may be shared in the following ways:

                    • With Friends: Your name, status, and availability are shared with friends you approve
                    • Discoverability: If enabled, your phone number or email can be searched by other users
                    • Service Providers: Apple provides the underlying CloudKit infrastructure

                    You control who can see your status through friend approvals and the discoverability toggle in Settings.
                    """
                )

                policySection(
                    title: "Your Rights",
                    content: """
                    You have the right to:

                    • Access your personal data stored in the app
                    • Correct inaccurate information in your profile
                    • Delete your account and all associated data
                    • Disable discoverability to prevent others from finding you
                    • Opt out of push notifications

                    To exercise these rights, use the Settings section of the app or contact us.
                    """
                )

                policySection(
                    title: "Children's Privacy",
                    content: """
                    OpenLine is not intended for children under the age of 13. We do not knowingly collect personal information from children under 13. If you believe we have collected information from a child under 13, please contact us immediately.
                    """
                )

                policySection(
                    title: "Changes to This Policy",
                    content: """
                    We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy in the app and updating the "Last updated" date.
                    """
                )

                policySection(
                    title: "Contact Us",
                    content: """
                    If you have questions about this Privacy Policy or our privacy practices, please contact us at:

                    Email: privacy@openlineapp.com
                    """
                )
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func policySection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
