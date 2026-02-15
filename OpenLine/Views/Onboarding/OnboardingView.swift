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
                    iconColor: .blue
                )
                .tag(0)
                
                OnboardingPageView(
                    icon: "clock.circle.fill",
                    title: "Smart Scheduling",
                    description: "Set your availability and let others know when you're free for calls.",
                    iconColor: .green
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
                .fontWeight(.semibold)
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
            
            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundColor(iconColor)
            
            VStack(spacing: 16) {
                Text(title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
    }
}
