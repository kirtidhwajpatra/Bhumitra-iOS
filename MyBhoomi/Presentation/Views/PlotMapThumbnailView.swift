//
//  PlotMapThumbnailView.swift
//  MyBhoomi
//
//  Satellite map thumbnail view for Saved Land cards.
//  Displays high-definition Apple Maps satellite imagery centered on the land plot
//  with the parcel boundary prominently highlighted in electric purple.
//

import SwiftUI

public struct PlotMapThumbnailView: View {
    public let record: SavedLandRecord
    public var size: CGFloat = 108
    
    @State private var snapshotImage: UIImage? = nil
    @State private var isLoading: Bool = true
    @Environment(\.colorScheme) private var colorScheme
    
    public init(record: SavedLandRecord, size: CGFloat = 108) {
        self.record = record
        self.size = size
    }
    
    public var body: some View {
        ZStack {
            if let image = snapshotImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipped()
                    .transition(.opacity.animation(.easeInOut(duration: 0.28)))
            } else {
                // Placeholder State while generating / fetching snapshot
                placeholderView
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.35 : 0.80),
                            Color.white.opacity(0.12),
                            Theme.Color.bhumitraPrimary.opacity(0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 6, x: 0, y: 3)
        .task(id: record.id) {
            await loadSnapshot()
        }
    }
    
    // MARK: - Placeholder View (Satellite Texture + Glowing Plot Silhouette)
    
    private var placeholderView: some View {
        ZStack {
            // Base satellite imagery texture
            Image("PlotHeroBg")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipped()
                .overlay(
                    Color.black.opacity(colorScheme == .dark ? 0.40 : 0.25)
                )
            
            // Stylized plot outline placeholder
            PlotPolygonSilhouette()
                .stroke(
                    Theme.Color.bhumitraPrimary.opacity(0.85),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                )
                .background(
                    PlotPolygonSilhouette()
                        .fill(Theme.Color.bhumitraTint)
                )
                .frame(width: size * 0.55, height: size * 0.58)
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
            }
        }
        .frame(width: size, height: size)
    }
    
    private func loadSnapshot() async {
        self.isLoading = true
        let img = await PlotMapSnapshotService.shared.getSnapshot(
            for: record,
            size: CGSize(width: size, height: size)
        )
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.25)) {
                self.snapshotImage = img
                self.isLoading = false
            }
        }
    }
}

// MARK: - Representative Cadastral Polygon Shape

public struct PlotPolygonSilhouette: Shape {
    public init() {}
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: rect.minX + w * 0.15, y: rect.minY + h * 0.75))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.05, y: rect.minY + h * 0.25))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.55, y: rect.minY + h * 0.05))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.90, y: rect.minY + h * 0.35))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.78, y: rect.minY + h * 0.88))
        path.closeSubpath()
        
        return path
    }
}
