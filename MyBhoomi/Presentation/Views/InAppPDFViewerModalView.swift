//
//  InAppPDFViewerModalView.swift
//  MyBhoomi
//
//  Production-grade in-app PDF document viewer with native zoom, pan, page scrolling, and export sheet.
//

import SwiftUI
import PDFKit

public struct PDFKitRepresentedView: UIViewRepresentable {
    public let url: URL
    
    public init(url: URL) {
        self.url = url
    }
    
    public class Coordinator {
        var loadedURL: URL?
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    public func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.backgroundColor = UIColor(Theme.Color.bhumitraBackground)
        
        if let document = PDFDocument(url: url) {
            pdfView.document = document
            pdfView.autoScales = true
            context.coordinator.loadedURL = url
        }
        return pdfView
    }
    
    public func updateUIView(_ uiView: PDFView, context: Context) {
        guard context.coordinator.loadedURL != url else { return }
        if let document = PDFDocument(url: url) {
            uiView.document = document
            uiView.autoScales = true
            context.coordinator.loadedURL = url
        }
    }
}

public struct InAppPDFViewerModalView: View {
    public let pdfURL: URL
    public let title: String
    public let subtitle: String?
    @Environment(\.dismiss) private var dismiss
    
    public init(pdfURL: URL, title: String = "Official RoR Document", subtitle: String? = nil) {
        self.pdfURL = pdfURL
        self.title = title
        self.subtitle = subtitle
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.Color.bhumitraBackground
                    .ignoresSafeArea()
                
                PDFKitRepresentedView(url: pdfURL)
                    .ignoresSafeArea(edges: .bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Theme.Color.bhumitraElevatedSurface)
                                .frame(width: 36, height: 36)
                                .overlay(Circle().stroke(Theme.Color.bhumitraBorder, lineWidth: 0.8))
                                .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Theme.Color.bhumitraPrimaryText)
                        }
                    }
                    .accessibilityLabel("Close PDF Viewer")
                }
                
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(title)
                            .font(.stackSansHeadline(size: 16, weight: .bold))
                            .foregroundColor(Theme.Color.bhumitraPrimaryText)
                            .lineLimit(1)
                        if let sub = subtitle, !sub.isEmpty {
                            Text(sub)
                                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                                .foregroundColor(Theme.Color.bhumitraSecondaryText)
                                .lineLimit(1)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(
                        item: pdfURL,
                        preview: SharePreview(
                            title,
                            image: Image(systemName: "doc.text.fill")
                        )
                    ) {
                        ZStack {
                            Circle()
                                .fill(Theme.Color.bhumitraElevatedSurface)
                                .frame(width: 36, height: 36)
                                .overlay(Circle().stroke(Theme.Color.bhumitraBorder, lineWidth: 0.8))
                                .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
                            
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Theme.Color.bhumitraPrimary)
                        }
                    }
                    .accessibilityLabel("Share or Export PDF")
                }
            }
        }
    }
}
