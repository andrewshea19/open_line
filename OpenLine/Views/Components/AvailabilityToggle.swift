//
//  AvailabilityToggle.swift
//  OpenLine
//
//  Created by Andrew Shea on 2/17/26.
//
import SwiftUI

// MARK: - Theme: Slack-Inspired Modern Design
// Clean, professional, friendly - with LED indicators as unique element

struct TurretTheme {
    // Clean backgrounds
    static let background = Color(UIColor.systemBackground)
    static let secondaryBg = Color(UIColor.secondarySystemBackground)
    static let tertiaryBg = Color(UIColor.tertiarySystemBackground)

    // Panel colors - for LED bezels
    static let panelDark = Color(red: 0.15, green: 0.16, blue: 0.18)
    static let panelLight = Color(red: 0.22, green: 0.23, blue: 0.25)
    static let bezel = Color(red: 0.28, green: 0.29, blue: 0.31)

    // Status LED colors - signature element
    static let ledGreen = Color(red: 0.18, green: 0.80, blue: 0.44)  // Slack-like green
    static let ledRed = Color(red: 0.90, green: 0.32, blue: 0.32)
    static let ledAmber = Color(red: 0.96, green: 0.70, blue: 0.20)
    static let ledOff = Color(red: 0.55, green: 0.57, blue: 0.60)

    // Accent colors - Slack-inspired
    static let accent = Color(red: 0.38, green: 0.20, blue: 0.55)  // Slack purple
    static let accentLight = Color(red: 0.48, green: 0.30, blue: 0.65)

    // Text - clean and readable
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    static let dimText = Color(UIColor.tertiaryLabel)

    // Corner radius - not too rounded, not too sharp
    static let cornerRadius: CGFloat = 10
    static let cornerRadiusSmall: CGFloat = 6

    // MARK: - Fonts (SF Pro Rounded - friendly but professional)

    /// Status text - prominent, clean
    static func statusFont(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// Section headers - clean rounded
    static func headerFont(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// Body text - standard readable font
    static func bodyFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// Caption/secondary text
    static func captionFont(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

// MARK: - Status Toggle Panel

struct TurretStatusPanel: View {
    @ObservedObject var viewModel: OpenLineViewModel
    @State private var showingStatusDetails = false

    private var ledColor: Color {
        switch viewModel.currentStatus {
        case StatusType.available.rawValue:
            return TurretTheme.ledGreen
        case StatusType.unavailable.rawValue:
            return TurretTheme.ledRed
        default:
            return TurretTheme.ledAmber
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Main toggle area - entire left section is tappable
            Button(action: toggleAvailability) {
                HStack(spacing: 14) {
                    // Status indicator
                    ledIndicator

                    // Status info
                    VStack(alignment: .leading, spacing: 3) {
                        Text(viewModel.currentStatus)
                            .font(TurretTheme.statusFont(size: 17))
                            .foregroundColor(TurretTheme.primaryText)

                        if let until = viewModel.statusUntil {
                            Text("Until \(until, formatter: timeFormatter)")
                                .font(TurretTheme.captionFont(size: 13))
                                .foregroundColor(TurretTheme.secondaryText)
                        } else {
                            Text("Tap to cycle status")
                                .font(TurretTheme.captionFont(size: 13))
                                .foregroundColor(TurretTheme.dimText)
                        }
                    }

                    Spacer()
                }
                .padding(.leading, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            // Divider
            Rectangle()
                .fill(Color(UIColor.separator))
                .frame(width: 1)
                .padding(.vertical, 12)

            // Details button - entire right section is tappable
            Button(action: { showingStatusDetails = true }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(TurretTheme.secondaryText)
                    .frame(width: 56)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .background(
            RoundedRectangle(cornerRadius: TurretTheme.cornerRadius)
                .fill(TurretTheme.secondaryBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: TurretTheme.cornerRadius)
                .strokeBorder(Color(UIColor.separator).opacity(0.4), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
        .sheet(isPresented: $showingStatusDetails) {
            StatusSelectionModal(viewModel: viewModel, isPresented: $showingStatusDetails)
        }
    }

    // MARK: - LED Indicator
    private var ledIndicator: some View {
        Circle()
            .fill(ledColor)
            .frame(width: 28, height: 28)
            .shadow(color: ledColor.opacity(0.4), radius: 4)
    }

    private func toggleAvailability() {
        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.cycleToNextStatus()
        }
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
}

// MARK: - Section Header

struct TurretSectionHeader: View {
    let title: String
    var count: Int? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(TurretTheme.headerFont(size: 13))
                .foregroundColor(TurretTheme.secondaryText)
                

            if let count = count {
                Spacer()
                Text("\(count)")
                    .font(TurretTheme.captionFont(size: 12))
                    .foregroundColor(TurretTheme.dimText)
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Card Container

struct TurretCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: TurretTheme.cornerRadius)
                    .fill(TurretTheme.secondaryBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: TurretTheme.cornerRadius)
                    .strokeBorder(Color(UIColor.separator).opacity(0.25), lineWidth: 0.5)
            )
    }
}

// MARK: - Legacy Compatibility

struct AvailabilityToggle: View {
    @ObservedObject var viewModel: OpenLineViewModel

    var body: some View {
        TurretStatusPanel(viewModel: viewModel)
    }
}

// Keep CiscoTheme as alias for compatibility
typealias CiscoTheme = TurretTheme
typealias CiscoCard = TurretCard
typealias CiscoSectionHeader = TurretSectionHeader

struct TurretButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
