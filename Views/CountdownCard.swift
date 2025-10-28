//
//  CountdownCard.swift
//  Countdown App
//
//  Created by Kevin on 25/7/25.
//

import SwiftUI

/// A reusable card component that displays countdown information with a gradient background
/// Used to show countdowns for non-working days, holidays, and long weekends
struct CountdownCard: View {
    // MARK: - Properties
    let title: String          // Main title (e.g., "Next Day Off", "Next Public Holiday")
    let target: Date          // The target date for the countdown
    let countdown: String     // Formatted countdown string (e.g., "3d 4h 12m")
    let background: LinearGradient  // Gradient background for the card
    let cardHeight: CGFloat   // Fixed height for consistent card sizing
    let subtitle: String?  // Optional subtitle (e.g., holiday name)

    init(
        title: String,
        target: Date,
        countdown: String,
        background: LinearGradient,
        cardHeight: CGFloat,
        subtitle: String? = nil
    ) {
        self.title = title
        self.target = target
        self.countdown = countdown
        self.background = background
        self.cardHeight = cardHeight
        self.subtitle = subtitle
    }

    var body: some View {
        ZStack {
            // Background card with rounded corners and shadow
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(background)
                .frame(maxWidth: .infinity, minHeight: cardHeight, maxHeight: cardHeight)
                .shadow(radius: 16)

            // Content stack with vertical spacing
            VStack(spacing: 24) {
                Spacer()
                
                // Main title with bold styling and shadow
                Text(title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .shadow(radius: 4)
                
                // Optional subtitle (typically holiday name)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.85))
                        .shadow(radius: 2)
                }
                
                // Target date display
                Text(target, style: .date)
                    .font(.title2)
                    .foregroundColor(.white)
                    .shadow(radius: 2)
                
                // Countdown timer with custom font
                Text(countdown)
                    .font(.countdownFont(size: 48))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .allowsTightening(true)
                    .foregroundColor(.white)
                    .shadow(radius: 4)
                
                Spacer()
            }
            .padding()
        }
        .padding(.horizontal, 24)
    }
}
