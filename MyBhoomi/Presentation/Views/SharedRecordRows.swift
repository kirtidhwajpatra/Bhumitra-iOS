//
//  SharedRecordRows.swift
//  MyBhoomi
//
//  Small shared views that used to live inside now-removed screens
//  (ParcelDetailSheet, KhatianDetailView). Kept here so live screens
//  (UnifiedRoRResultView, LocationDetailSheet, LandPassportDetailView,
//  MainView) keep working.
//

import SwiftUI
import UIKit

struct ModernOwnerRow: View {
    let owner: OwnerEntry
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(primaryPurple)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(owner.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.Color.primaryText)
                
                if let share = owner.share, !share.isEmpty {
                    Text("Share: \(share)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let khata = owner.khataNumber, !khata.isEmpty {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("KHATA")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text(khata)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.primary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct ModernRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.Color.primaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

public struct ShareSheet: UIViewControllerRepresentable {
    public let activityItems: [Any]
    public let applicationActivities: [UIActivity]?
    public let excludedActivityTypes: [UIActivity.ActivityType]?
    @Environment(\.dismiss) private var dismiss
    
    public init(
        activityItems: [Any],
        applicationActivities: [UIActivity]? = nil,
        excludedActivityTypes: [UIActivity.ActivityType]? = nil
    ) {
        self.activityItems = activityItems
        self.applicationActivities = applicationActivities
        self.excludedActivityTypes = excludedActivityTypes
    }
    
    public func makeUIViewController(context: Context) -> UIViewController {
        let container = UIViewController()
        container.view.backgroundColor = .clear
        return container
    }
    
    public func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard !context.coordinator.hasPresented else { return }
        context.coordinator.hasPresented = true
        
        let activityVC = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        activityVC.excludedActivityTypes = excludedActivityTypes
        
        activityVC.completionWithItemsHandler = { [weak uiViewController] _, _, _, _ in
            DispatchQueue.main.async {
                uiViewController?.dismiss(animated: true) {
                    dismiss()
                }
            }
        }
        
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = uiViewController.view
            popover.sourceRect = CGRect(x: uiViewController.view.bounds.midX, y: uiViewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        DispatchQueue.main.async {
            uiViewController.present(activityVC, animated: true)
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    public class Coordinator {
        var hasPresented = false
    }
}
