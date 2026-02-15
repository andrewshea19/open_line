//
//  GlassComponents.swift
//  OpenLine
//
//  Created by Andrew Shea on 8/9/25.
//
import SwiftUI

// MARK: - Glass Card Modifier
struct GlassCardStyle: ViewModifier {
    var cornerRadius: CGFloat = 20
    var padding: CGFloat = 16
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            }
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20, padding: CGFloat = 16) -> some View {
        modifier(GlassCardStyle(cornerRadius: cornerRadius, padding: padding))
    }
}

// MARK: - Glass Button Style
struct GlassButtonStyle: ButtonStyle {
    var isPrimary: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                Group {
                    if isPrimary {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.accentColor.opacity(0.2))
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(isPrimary ? Color.accentColor.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Liquid Glass Background
struct LiquidGlassBackground: View {
    var colors: [Color] = [
        .blue.opacity(0.18),
        .indigo.opacity(0.22),
        .white.opacity(0.12)
    ]
    var blurRadius: CGFloat = 60
    
    var body: some View {
        ZStack {
            // Gradient base
            LinearGradient(
                colors: colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blur(radius: blurRadius)
            
            // Overlay material
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.9)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Glass Status Card
struct GlassStatusCard<Content: View>: View {
    let content: Content
    var gradient: LinearGradient
    
    init(
        gradient: LinearGradient = LinearGradient(
            colors: [Color.blue.opacity(0.7), Color.indigo.opacity(0.85)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        @ViewBuilder content: () -> Content
    ) {
        self.gradient = gradient
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            // Base gradient
            gradient
            
            // Glass overlay
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            
            content
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Modern Icon Badge
struct ModernIconBadge: View {
    let icon: String
    let color: Color
    var size: CGFloat = 44
    var useNeutralStyle: Bool = false
    
    var body: some View {
        ZStack {
            if useNeutralStyle {
                Circle()
                    .fill(Color.white)
            } else {
                Circle()
                    .fill(color.opacity(0.15))
            }

            Image(systemName: icon)
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(useNeutralStyle ? .primary : color)
        }
        .frame(width: size, height: size)
        .shadow(color: useNeutralStyle ? .clear : color.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

