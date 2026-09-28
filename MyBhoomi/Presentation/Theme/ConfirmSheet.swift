//  ConfirmSheet.swift
//  MyBhoomi
//
//  The ONE confirmation surface app-wide (sign out, clear cache, delete
//  account, remove saved land…). Replaces system alerts, whose iOS 26
//  styling paints "Cancel" as the prominent purple button and the actual
//  action as a grey one — the opposite of what the user came to do.
//
//  A short bottom sheet on the shared sheet background: tone-tinted icon,
//  title, one-line message, optional context chip, then the action as a CTA
//  and a quiet Cancel below it.
//
//  Usage (drop-in for `.alert(…, isPresented:)`):
//      .confirmSheet(isPresented: $showSignOut,
//                    icon: "rectangle.portrait.and.arrow.right",
//                    title: "Sign out?",
//                    message: "…",
//                    confirmTitle: "Sign out") { authManager.signOut() }
//
//  `onConfirm` runs AFTER the sheet has finished dismissing, so it is safe
//  to dismiss the presenting screen or present something else from it.

import SwiftUI

public enum ConfirmTone {
    /// Irreversible or session-ending: red icon, red action.
    case destructive
    /// Ordinary confirmation: brand icon, primary action.
    case standard
}

private struct ConfirmSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    let icon: String
    let tone: ConfirmTone
    let title: String
    let message: String
    let context: String?
    let confirmTitle: String
    let onConfirm: () -> Void

    @State private var confirmed = false

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented, onDismiss: {
            guard confirmed else { return }
            confirmed = false
            onConfirm()
        }) {
            ConfirmSheetContent(
                icon: icon, tone: tone, title: title, message: message,
                context: context, confirmTitle: confirmTitle,
                onConfirm: {
                    confirmed = true
                    isPresented = false
                },
                onCancel: { isPresented = false }
            )
        }
    }
}

private struct ConfirmSheetContent: View {
    let icon: String
    let tone: ConfirmTone
    let title: String
    let message: String
    let context: String?
    let confirmTitle: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var height: CGFloat = 320

    private var toneColor: Color {
        tone == .destructive ? Theme.Color.bhumitraError : Theme.Color.bhumitraPrimary
    }

    private var toneSurface: Color {
        tone == .destructive ? Theme.Color.bhumitraErrorSurface : Theme.Color.bhumitraTint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(toneColor)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(toneSurface))
                    .accessibilityHidden(true)
                Spacer()
                SheetIconButton("xmark", accessibilityLabel: "Close", action: onCancel)
            }

            Text(title)
                .font(.googleSans(size: 22, weight: .semibold))
                .foregroundColor(Theme.Color.bhumitraPrimaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16)
                .accessibilityAddTraits(.isHeader)

            Text(message)
                .font(.googleSans(size: 15, weight: .regular))
                .foregroundColor(Theme.Color.bhumitraSecondaryText)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            if let context, !context.isEmpty {
                Text(context)
                    .font(.googleSans(size: 13, weight: .medium))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background(Capsule().fill(SheetChrome.controlFill))
                    .padding(.top, 14)
            }

            VStack(spacing: 10) {
                Button {
                    Theme.haptic(.medium)
                    onConfirm()
                } label: {
                    Text(confirmTitle)
                }
                .buttonStyle(CTAButtonStyle(tone == .destructive ? .destructive : .primary))

                Button("Cancel", action: onCancel)
                    .buttonStyle(CTAButtonStyle(.neutral))
            }
            .padding(.top, 24)
        }
        .padding(.horizontal, SheetChrome.inset)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .presentationDetents([.height(height)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(28)
        .presentationBackground(SheetChrome.background)
    }
}

extension View {
    /// Shared confirmation sheet — see `ConfirmSheet.swift`.
    public func confirmSheet(
        isPresented: Binding<Bool>,
        icon: String,
        tone: ConfirmTone = .destructive,
        title: String,
        message: String,
        context: String? = nil,
        confirmTitle: String,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(ConfirmSheetModifier(
            isPresented: isPresented, icon: icon, tone: tone, title: title,
            message: message, context: context, confirmTitle: confirmTitle,
            onConfirm: onConfirm
        ))
    }
}
