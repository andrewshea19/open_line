//
//  TermsOfServiceView.swift
//  OpenLine
//
//  Created by Andrew Shea on 1/27/26.
//
import SwiftUI

struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Terms of Service")
                    .font(TurretTheme.statusFont(size: 28, weight: .bold))

                Text("Last updated: January 27, 2026")
                    .font(TurretTheme.captionFont(size: 13))
                    .foregroundColor(.secondary)

                termsSection(
                    title: "1. Acceptance of Terms",
                    content: """
                    By downloading, installing, or using OpenLine ("the App"), you agree to be bound by these Terms of Service ("Terms"). If you do not agree to these Terms, do not use the App.

                    These Terms constitute a legal agreement between you and OpenLine. We reserve the right to modify these Terms at any time, and such modifications will be effective immediately upon posting in the App.
                    """
                )

                termsSection(
                    title: "2. Description of Service",
                    content: """
                    OpenLine is a social availability app that allows you to:

                    • Share your availability status with friends
                    • See when your friends are available
                    • Send and receive friend requests
                    • Schedule recurring availability windows

                    The App requires an active iCloud account and internet connection to function properly.
                    """
                )

                termsSection(
                    title: "3. User Accounts",
                    content: """
                    To use OpenLine, you must:

                    • Be at least 13 years of age
                    • Have a valid Apple ID with iCloud enabled
                    • Provide accurate profile information
                    • Maintain the security of your account

                    You are responsible for all activity that occurs under your account.
                    """
                )

                termsSection(
                    title: "4. User Responsibilities",
                    content: """
                    When using OpenLine, you agree to:

                    • Use the App only for lawful purposes
                    • Not harass, abuse, or harm other users
                    • Not impersonate others or provide false information
                    • Not attempt to gain unauthorized access to other accounts
                    • Not use the App to spam or send unsolicited messages
                    • Not reverse engineer or attempt to extract source code
                    • Comply with all applicable laws and regulations

                    Violation of these responsibilities may result in account suspension or termination.
                    """
                )

                termsSection(
                    title: "5. Content and Conduct",
                    content: """
                    You retain ownership of any content you create in the App (such as status messages). By using the App, you grant us a limited license to display this content to your approved friends.

                    You agree not to post content that is:
                    • Illegal, harmful, or threatening
                    • Harassing, defamatory, or invasive of privacy
                    • Infringing on intellectual property rights
                    • Sexually explicit or obscene
                    • Promoting violence or discrimination
                    """
                )

                termsSection(
                    title: "6. Intellectual Property",
                    content: """
                    The App, including its design, features, and content (excluding user-generated content), is owned by OpenLine and protected by copyright, trademark, and other intellectual property laws.

                    You may not copy, modify, distribute, sell, or lease any part of the App without our written permission.
                    """
                )

                termsSection(
                    title: "7. Disclaimer of Warranties",
                    content: """
                    THE APP IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED.

                    We do not warrant that:
                    • The App will be uninterrupted or error-free
                    • Defects will be corrected
                    • The App is free of viruses or harmful components
                    • The results of using the App will meet your requirements

                    Your use of the App is at your own risk.
                    """
                )

                termsSection(
                    title: "8. Limitation of Liability",
                    content: """
                    TO THE MAXIMUM EXTENT PERMITTED BY LAW, OPENLINE SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, OR ANY LOSS OF PROFITS OR REVENUES.

                    Our total liability for any claims arising from your use of the App shall not exceed the amount you paid for the App in the past twelve months.
                    """
                )

                termsSection(
                    title: "9. Termination",
                    content: """
                    You may stop using the App at any time by deleting it from your device.

                    We may suspend or terminate your access to the App at any time, with or without cause, with or without notice. Upon termination, your right to use the App will immediately cease.
                    """
                )

                termsSection(
                    title: "10. Governing Law",
                    content: """
                    These Terms shall be governed by and construed in accordance with the laws of the United States, without regard to its conflict of law provisions.

                    Any disputes arising from these Terms or your use of the App shall be resolved through binding arbitration in accordance with the rules of the American Arbitration Association.
                    """
                )

                termsSection(
                    title: "11. Contact Information",
                    content: """
                    If you have any questions about these Terms, please contact us at:

                    Email: legal@openlineapp.com
                    """
                )
            }
            .padding()
        }
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func termsSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(TurretTheme.statusFont(size: 16))

            Text(content)
                .font(TurretTheme.bodyFont(size: 15))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        TermsOfServiceView()
    }
}
