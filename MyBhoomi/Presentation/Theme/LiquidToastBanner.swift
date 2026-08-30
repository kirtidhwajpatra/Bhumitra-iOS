import SwiftUI

// ============================================================
// MARK: - LIQUID GLASS TOAST NOTIFICATION BANNER
// ============================================================

public struct LiquidToastBanner: View {
    @ObservedObject private var manager = SavedLandManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    public init() {}
    
    public var body: some View {
        if manager.isToastVisible, let title = manager.toastTitle {
            VStack {
                HStack(spacing: 12) {
                    // Accent Bookmark Icon with subtle glass backing
                    ZStack {
                        Circle()
                            .fill(
                                colorScheme == .dark
                                    ? Color(red: 116/255, green: 18/255, blue: 250/255).opacity(0.3)
                                    : Color(red: 116/255, green: 18/255, blue: 250/255).opacity(0.12)
                            )
                            .frame(width: 38, height: 38)
                        
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(red: 116/255, green: 18/255, blue: 250/255))
                    }
                    
                    // Message Copy
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                            .foregroundColor(colorScheme == .dark ? .white : Color(red: 17/255, green: 24/255, blue: 39/255))
                            .lineLimit(1)
                        
                        if let subtitle = manager.toastSubtitle {
                            Text(subtitle)
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundColor(colorScheme == .dark ? Color(white: 0.70) : Color(red: 100/255, green: 105/255, blue: 115/255))
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer(minLength: 4)
                    
                    // Dismiss X
                    Button {
                        Theme.haptic(.light)
                        manager.dismissToast()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? Color(white: 0.60) : Color.black.opacity(0.50))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    colorScheme == .dark
                        ? Color(red: 24/255, green: 24/255, blue: 28/255).opacity(0.96)
                        : Color.white.opacity(0.96)
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.12),
                    radius: 16,
                    x: 0,
                    y: 6
                )
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .zIndex(9999)
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onEnded { value in
                        if value.translation.height < -15 {
                            manager.dismissToast()
                        }
                    }
            )
        }
    }
}

// MARK: - View Modifier for Easy Toast Overlay Attachment

public struct LiquidToastOverlayModifier: ViewModifier {
    public func body(content: Content) -> some View {
        ZStack {
            content
            LiquidToastBanner()
        }
    }
}

extension View {
    public func liquidToastOverlay() -> some View {
        self.modifier(LiquidToastOverlayModifier())
    }
}
