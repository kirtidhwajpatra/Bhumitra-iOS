//
//  StackSansHeadlineFont.swift
//  MyBhoomi
//
//  Dedicated Typography Extension for Stack Sans Headline
//

import SwiftUI
import UIKit

public extension Font {
    /// Returns a SwiftUI Font using Stack Sans Headline with dynamic fallback to Google Sans and System Rounded.
    static func stackSansHeadline(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        let candidateNames: [String]
        switch weight {
        case .bold, .heavy, .black:
            candidateNames = [
                "StackSansHeadline-Bold",
                "StackSansHeadline-Black",
                "StackSansHeadline-SemiBold",
                "StackSansHeadline",
                "StackSans-Bold",
                "GoogleSans-Bold"
            ]
        case .semibold, .medium:
            candidateNames = [
                "StackSansHeadline-SemiBold",
                "StackSansHeadline-Medium",
                "StackSansHeadline",
                "StackSans-Medium",
                "GoogleSans-Medium"
            ]
        default:
            candidateNames = [
                "StackSansHeadline-Regular",
                "StackSansHeadline",
                "StackSans-Regular",
                "GoogleSans-Regular"
            ]
        }
        
        for name in candidateNames {
            if UIFont(name: name, size: size) != nil {
                return .custom(name, size: size)
            }
        }
        return .system(size: size, weight: weight)
    }
}
