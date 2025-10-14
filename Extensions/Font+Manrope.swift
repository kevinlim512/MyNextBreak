//
//  Font+Manrope.swift
//  Countdown App
//
//  Created by Kevin on 25/7/25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Font extension providing Manrope custom font utilities
/// Includes fallback mechanisms for when the custom font isn't available
extension Font {
    // MARK: - Variable Font Functions
    
    /// Manrope with custom weight (100-900)
    /// Provides the most flexible way to use Manrope with any weight
    static func manrope(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return Font.custom("Manrope", size: size).weight(weight)
    }
    
    /// Manrope Light (300) - for subtle text
    static func manropeLight(size: CGFloat) -> Font {
        return Font.custom("Manrope", size: size).weight(.light)
    }
    
    /// Manrope Regular (400) - standard body text
    static func manropeRegular(size: CGFloat) -> Font {
        return Font.custom("Manrope", size: size).weight(.regular)
    }
    
    /// Manrope Medium (500) - slightly emphasized text
    static func manropeMedium(size: CGFloat) -> Font {
        return Font.custom("Manrope", size: size).weight(.medium)
    }
    
    /// Manrope SemiBold (600) - for headings and important text
    static func manropeSemiBold(size: CGFloat) -> Font {
        return Font.custom("Manrope", size: size).weight(.semibold)
    }
    
    /// Manrope Bold (700) - for strong emphasis
    static func manropeBold(size: CGFloat) -> Font {
        return Font.custom("Manrope", size: size).weight(.bold)
    }
    
    /// Manrope ExtraBold (800) - for maximum emphasis
    static func manropeExtraBold(size: CGFloat) -> Font {
        return Font.custom("Manrope", size: size).weight(.heavy)
    }
    
    // MARK: - Countdown Font with Fallback
    
    /// Countdown font with fallback to system font if Manrope isn't available
    /// Used specifically for countdown timer display with medium weight
    static func countdownFont(size: CGFloat) -> Font {
        #if canImport(UIKit)
        if UIFont(name: "Manrope", size: size) != nil {
            return Font.custom("Manrope", size: size).weight(.medium)
        } else {
            return Font.system(size: size, weight: .medium, design: .default)
        }
        #else
        return Font.system(size: size, weight: .medium, design: .default)
        #endif
    }
}
