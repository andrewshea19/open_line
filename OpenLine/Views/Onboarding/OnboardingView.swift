//
//  OnboardingView.swift
//  OpenLine
//
//  Created by Andrew Shea on 8/8/25.
//
import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0

    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                OnboardingPageView(
                    icon: "phone.circle.fill",
                    title: "Stay Connected",
                    description: "Know when your friends and family are available for spontaneous phone calls.",
                    iconColor: TurretTheme.ledGreen
                )
                .tag(0)

                OnboardingPageView(
                    icon: "clock.circle.fill",
                    title: "Smart Scheduling",
                    description: "Set your availability and let others know when you're free for calls.",
                    iconColor: TurretTheme.ledAmber
                )
                .tag(1)

                OnboardingPageView(
                    icon: "icloud.circle.fill",
                    title: "Stay Synchronized",
                    description: "Connect with friends and get real-time status updates when available.",
                    iconColor: .purple
                )
                .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))

            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                    .font(TurretTheme.bodyFont(size: 17))
                }

                Spacer()

                Button(currentPage == 2 ? "Get Started" : "Next") {
                    if currentPage == 2 {
                        isPresented = false
                    } else {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                }
                .font(TurretTheme.statusFont(size: 17))
            }
            .padding()
        }
    }
}

struct OnboardingPageView: View {
    let icon: String
    let title: String
    let description: String
    let iconColor: Color

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // LED-style icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .blur(radius: 10)

                Image(systemName: icon)
                    .font(.system(size: 70))
                    .foregroundColor(iconColor)
            }

            VStack(spacing: 16) {
                Text(title)
                    .font(TurretTheme.statusFont(size: 28, weight: .bold))

                Text(description)
                    .font(TurretTheme.bodyFont(size: 17))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }

            Spacer()
        }
    }
}
