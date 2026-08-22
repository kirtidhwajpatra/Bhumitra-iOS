import SwiftUI

struct SearchBarView: View {
    @ObservedObject var viewModel: MapViewModel
    @Binding var text: String
    var onCommit: () -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(isFocused ? Theme.Color.primary : Theme.Color.indigo)
                .symbolEffect(.bounce, value: isFocused)
            
            TextField("Search village, area or plot...", text: $text)
                .font(Theme.Typography.secondaryBody)
                .submitLabel(.search)
                .onSubmit(onCommit)
                .focused($isFocused)
            
            if !text.isEmpty {
                Button(action: { 
                    hapticFeedback(.light)
                    text = "" 
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Theme.Color.tertiaryText)
                }
                .buttonStyle(TactileGlassButtonStyle())
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 15)
        .liquidGlassCard(tint: isFocused ? Theme.Color.primary : Theme.Color.indigo, radius: Theme.Radius.medium, isEmphasized: isFocused)
        .animation(Theme.Animation.emphasis, value: isFocused)
    }
}
