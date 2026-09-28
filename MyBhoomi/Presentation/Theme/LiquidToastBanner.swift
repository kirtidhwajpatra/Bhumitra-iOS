import SwiftUI

// ============================================================
// MARK: - SAVED-LAND TOAST (shared notice style)
// ============================================================

/// Top toast for SavedLandManager confirmations ("Saved", "Removed"),
/// rendered with the shared MapStatusPill so it matches every other notice.
public struct LiquidToastBanner: View {
    @ObservedObject private var manager = SavedLandManager.shared

    public init() {}

    public var body: some View {
        if manager.isToastVisible, let title = manager.toastTitle {
            VStack {
                MapStatusPill(
                    icon: "bookmark.fill",
                    tone: .neutral,
                    title: title,
                    detail: manager.toastSubtitle,
                    onDismiss: { manager.dismissToast() }
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
