import SwiftUI

struct SearchBarView: View {
    @ObservedObject var viewModel: MapViewModel
    @Binding var text: String
    var onCommit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.brandGradient)
            
            TextField("Search village, area or plot...", text: $text)
                .font(.system(size: 16, weight: .regular))
                .submitLabel(.search)
                .onSubmit(onCommit)
            
            if !text.isEmpty {
                Button(action: { 
                    hapticFeedback(.light)
                    text = "" 
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.leading, 20)
        .padding(.trailing, 16)
        .padding(.vertical, 14)
        .background(
            ZStack {
                Color.white
                Theme.primary.opacity(0.02)
            }
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.primary.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 20, x: 0, y: 10)
    }
}
