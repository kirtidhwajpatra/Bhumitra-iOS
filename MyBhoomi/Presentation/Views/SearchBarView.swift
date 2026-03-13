import SwiftUI

struct SearchBarView: View {
    @Binding var text: String
    var onCommit: () -> Void
    

    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(primaryPurple)
            
            TextField("Search village or plot...", text: $text, onCommit: onCommit)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.regular)
                .submitLabel(.search)
            
            if !text.isEmpty {
                Button(action: { 
                    hapticFeedback(.light)
                    text = "" 
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(primaryPurple.opacity(0.4))
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.08), radius: 25, x: 0, y: 12)
    }
}
