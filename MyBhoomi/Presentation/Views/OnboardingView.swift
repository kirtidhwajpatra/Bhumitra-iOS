//
//  OnboardingView.swift
//  MyBhoomi
//
//  First-launch intro, shown once. Three short pages: what the app does, how
//  plot searches work, and where the data comes from (not an official
//  document). Same chrome as LoginView: SheetChrome background, leading
//  headline, CTA pinned to the bottom.
//

import SwiftUI

enum OnboardingState {
    static let completedKey = "bhumitra_onboarding_completed_v1"
    /// Set when the user chooses "Not now" on the launch sign-in screen.
    static let guestChosenKey = "bhumitra_guest_mode_chosen_v1"
}

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page = 0
    @State private var startedAt = Date()

    private struct Page: Identifiable {
        let id: Int
        let icon: String
        let title: String
        let body: String
        let points: [(icon: String, text: String)]
    }

    private let pages: [Page] = [
        Page(id: 0, icon: "map",
             title: "See every plot on the map",
             body: "Search your village and the plot boundaries appear over satellite imagery.",
             points: [("magnifyingglass", "Find a village by name"),
                      ("hand.tap", "Tap any plot to open it"),
                      ("location", "Or jump to where you're standing")]),
        Page(id: 1, icon: "doc.text.magnifyingglass",
             title: "Open the land record",
             body: "Each plot search shows the Record of Rights (RoR): owners, khata, area and land type.",
             points: [("gift", "Your first searches are free"),
                      ("arrow.uturn.backward", "Plots you've opened stay open, no second charge"),
                      ("square.and.arrow.up", "Save or share the record")]),
        Page(id: 2, icon: "checkmark.shield",
             title: "Good to know",
             body: "Bhumitra is an independent app. It isn't affiliated with the Government of Odisha.",
             points: [("server.rack", "Records come from the public Bhulekh portal (bhulekh.ori.nic.in)"),
                      ("exclamationmark.triangle", "For information only, not a legal or certified copy"),
                      ("building.columns", "For certified copies, visit your Tahasil office")]),
    ]

    private var isLast: Bool { page == pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if !isLast {
                    Button("Skip") { finish() }
                        .font(.googleSans(size: 15, weight: .medium))
                        .foregroundColor(Theme.Color.bhumitraSecondaryText)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityHint("Skips the introduction")
                }
            }
            .frame(height: 44)
            .padding(.horizontal, SheetChrome.inset)
            .padding(.top, 8)

            TabView(selection: $page) {
                ForEach(pages) { p in
                    pageView(p).tag(p.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.25), value: page)

            VStack(spacing: 18) {
                pageDots
                Button(isLast ? "Get started" : "Continue") {
                    Theme.haptic(.light)
                    if isLast { finish() } else { page += 1 }
                }
                .buttonStyle(.primaryCTA)
            }
            .padding(.horizontal, SheetChrome.inset)
            .padding(.bottom, 16)
        }
        .background(SheetChrome.background.ignoresSafeArea())
        .onAppear {
            startedAt = Date()
            AnalyticsService.shared.log(.onboardingStarted(source: "first_launch"))
        }
    }

    private func pageView(_ p: Page) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: p.icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(Theme.Color.bhumitraPrimary)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(Theme.Color.bhumitraTint))
                    .accessibilityHidden(true)

                Text(p.title)
                    .font(.stackSansHeadline(size: 30, weight: .semibold))
                    .tracking(-0.6)
                    .foregroundColor(Theme.Color.bhumitraPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 28)

                Text(p.body)
                    .font(.googleSans(size: 16, weight: .regular))
                    .foregroundColor(Theme.Color.bhumitraSecondaryText)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(p.points.enumerated()), id: \.offset) { idx, point in
                        HStack(spacing: 14) {
                            Image(systemName: point.icon)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Theme.Color.bhumitraSecondaryText)
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(SheetChrome.controlFill))
                                .accessibilityHidden(true)
                            Text(point.text)
                                .font(.googleSans(size: 15, weight: .regular))
                                .foregroundColor(Theme.Color.bhumitraPrimaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 12)
                        if idx < p.points.count - 1 {
                            SheetHairline().padding(.leading, 48)
                        }
                    }
                }
                .padding(.top, 28)
            }
            .padding(.horizontal, SheetChrome.inset)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(pages) { p in
                Capsule()
                    .fill(p.id == page ? Theme.Color.bhumitraPrimary : Theme.Color.bhumitraBorder)
                    .frame(width: p.id == page ? 20 : 8, height: 8)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: page)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(page + 1) of \(pages.count)")
    }

    private func finish() {
        let seconds = Int(Date().timeIntervalSince(startedAt))
        AnalyticsService.shared.log(.onboardingCompleted(durationSeconds: seconds))
        onFinish()
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
