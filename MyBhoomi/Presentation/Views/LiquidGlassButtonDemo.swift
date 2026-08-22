//
//  WhatsppStyleButton.swift
//  MyBhoomi
//
//  Created by Uday on 22/08/26.
//

import SwiftUI

struct LiquidGlassButtonsDemo: View {

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {

                    // MARK: - 1. Short Button
                    section("1. Short Button") {
                        Button {
                            print("Short tapped")
                        } label: {
                            Text("Save")
                                .font(.headline)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.accentColor)
                    }

                    // MARK: - 2. Medium Button
                    section("2. Medium Button") {
                        Button {
                            print("Medium tapped")
                        } label: {
                            Label("Continue", systemImage: "arrow.right")
                                .font(.headline)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.accentColor)
                    }

                    // MARK: - 3. Long Button
                    section("3. Long Button") {
                        Button {
                            print("Long tapped")
                        } label: {
                            HStack {
                                Text("Start Recording")
                                Spacer()
                                Image(systemName: "mic.fill")
                            }
                            .font(.headline)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.accentColor)
                    }

                  
                    
                     
                    
                    
                    // MARK: - 5. Icon + Text
                    section("5. Icon + Text") {
                        Button {
                            print("Add tapped")
                        } label: {
                            Label("Add Instrument", systemImage: "plus")
                                .font(.headline)
                                .padding(.horizontal, 22)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.glassProminent)
                    }

                    // MARK: - 6. Glass Secondary
                    section("6. Secondary Glass") {
                        Button {
                            print("Cancel tapped")
                        } label: {
                            Text("Cancel")
                                .font(.headline)
                                .padding(.horizontal, 26)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.glass)
                    }

                    // MARK: - 7. Dropdown
                    section("7. Dropdown Button") {
                        Menu {
                            Button("Piano") {
                                print("Piano")
                            }

                            Button("Guitar") {
                                print("Guitar")
                            }

                            Button("Drums") {
                                print("Drums")
                            }

                            Button("Bass") {
                                print("Bass")
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "pianokeys")
                                
                                Text("Choose Instrument")
                                
                                Image(systemName: "chevron.down")
                                    .font(.caption.weight(.bold))
                            }
                            .font(.headline)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.glass)
                    }

                    // MARK: - 8. Compact Icon Button
                    section("8. Compact Icon") {
                        HStack(spacing: 16) {

                            Button {
                                print("Undo")
                            } label: {
                                Image(systemName: "arrow.uturn.backward")
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.glass)

                            Button {
                                print("Redo")
                            } label: {
                                Image(systemName: "arrow.uturn.forward")
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.glass)

                            Button {
                                print("Settings")
                            } label: {
                                Image(systemName: "gearshape.fill")
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.glass)
                        }
                    }

                    // MARK: - 9. Large Hero Button
                    section("9. Large Hero Button") {
                        Button {
                            print("Create tapped")
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "wand.and.stars")
                                    .font(.title)

                                Text("Make It Studio Quality")
                                    .font(.headline)

                                Text("Enhance your recording")
                                    .font(.subheadline)
                                    .opacity(0.7)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.green)
                    }

                    // MARK: - 10. Pill Button
                    section("10. Pill Button") {
                        Button {
                            print("Upgrade tapped")
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                Text("Upgrade")
                            }
                            .font(.headline)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.accentColor)
                        .clipShape(Capsule())
                    }
                }
                .padding(20)
            }
            .navigationTitle("Liquid Glass")
            .background {
                LinearGradient(
                    colors: [
                        Color.green.opacity(0.12),
                        Color.black.opacity(0.04),
                        Color.blue.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - Section Helper

    @ViewBuilder
    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {

        VStack(alignment: .leading, spacing: 14) {

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            content()
                .frame(maxWidth: .infinity)
        }
    }
}


// MARK: - Preview

#Preview {
    LiquidGlassButtonsDemo()
}
