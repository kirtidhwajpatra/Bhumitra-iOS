import SwiftUI

// ============================================================
// MARK: - BHUMITRA SAVED LANDS VAULT (TOP 1% LUXURY REDESIGN)
// ============================================================

/// Premium on-device vault presenting all bookmarked and saved land parcels.
/// Features authentic district photography headers, bold typography, generous rounded cards,
/// real-time search filtering, acreage tallying, and instant offline passport viewing.
public struct SavedLandsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var savedManager = SavedLandManager.shared
    
    @State private var searchText: String = ""
    @State private var selectedRecordForDetail: SavedLandRecord? = nil
    @State private var showDeleteConfirmation: Bool = false
    @State private var recordToDelete: SavedLandRecord? = nil
    
    public init() {}
    
    // MARK: - Filtered Records
    
    private var filteredRecords: [SavedLandRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            return savedManager.savedRecords
        }
        return savedManager.savedRecords.filter { record in
            record.plotNumber.lowercased().contains(query) ||
            record.khatianNumber.lowercased().contains(query) ||
            record.villageName.lowercased().contains(query) ||
            record.districtName.lowercased().contains(query) ||
            record.tahasilName.lowercased().contains(query) ||
            (record.landType?.lowercased().contains(query) ?? false) ||
            record.owners.contains { $0.lowercased().contains(query) }
        }
    }
    
    // MARK: - Dynamic Theme Palette
    
    private var pageBackground: Color {
        colorScheme == .dark
            ? Color(red: 12/255, green: 13/255, blue: 16/255)
            : Color(red: 243/255, green: 245/255, blue: 249/255)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark
            ? Color(red: 22/255, green: 23/255, blue: 28/255)
            : Color.white
    }
    
    private var primaryText: Color {
        colorScheme == .dark ? .white : Color(red: 17/255, green: 24/255, blue: 39/255)
    }
    
    private var secondaryText: Color {
        colorScheme == .dark ? Color(white: 0.65) : Color(red: 100/255, green: 105/255, blue: 115/255)
    }
    
    private var electricPurple: Color {
        Color(red: 116/255, green: 18/255, blue: 250/255)
    }
    
    // MARK: - Main Body
    
    public var body: some View {
        NavigationStack {
            ZStack {
                pageBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 1. Top Large Header Bar
                    headerBar
                    
                    if savedManager.savedRecords.isEmpty {
                        emptyStateView
                    } else {
                        // 2. Search & Large Statistics Strip
                        VStack(spacing: 14) {
                            searchBar
                            metricsSummaryStrip
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 14)
                        
                        // 3. Saved Land Cards Feed
                        if filteredRecords.isEmpty {
                            noSearchResultsView
                        } else {
                            ScrollView(.vertical, showsIndicators: false) {
                                LazyVStack(spacing: 22) {
                                    ForEach(filteredRecords) { record in
                                        savedLandCard(record: record)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 42)
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(item: $selectedRecordForDetail) { record in
                LandPassportDetailView(result: record.toSearchResult)
            }
            .alert("Remove Saved Land?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { recordToDelete = nil }
                Button("Remove", role: .destructive) {
                    if let target = recordToDelete {
                        savedManager.remove(recordID: target.id)
                        recordToDelete = nil
                    }
                }
            } message: {
                if let target = recordToDelete {
                    Text("Are you sure you want to remove Plot \(target.plotNumber) in \(target.villageName) from your on-device saved lands?")
                }
            }
            .liquidToastOverlay()
        }
    }
    
    // MARK: - 1. Top Header Bar
    
    private var headerBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Saved Lands")
                    .font(.googleSans(size: 32, weight: .bold))
                    .foregroundColor(primaryText)
                
                Text("Offline Land Records Vault")
                    .font(.googleSans(size: 14.5, weight: .medium))
                    .foregroundColor(secondaryText)
            }
            
            Spacer()
            
            // Apple Liquid Glass Circle Dismiss Button
            Button {
                Theme.haptic(.light)
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundColor(primaryText)
                    .frame(width: 42, height: 42)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 4)
    }
    
    // MARK: - 2. Large Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(secondaryText)
            
            TextField("Search plot, khata, village, owner...", text: $searchText)
                .font(.googleSans(size: 16.5, weight: .regular))
                .foregroundColor(primaryText)
            
            if !searchText.isEmpty {
                Button {
                    Theme.haptic(.light)
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(secondaryText)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(
            colorScheme == .dark
                ? Color(red: 24/255, green: 25/255, blue: 30/255)
                : Color.white
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.04), radius: 8, y: 2)
    }
    
    // MARK: - 3. Large Metrics Summary Strip
    
    private var metricsSummaryStrip: some View {
        HStack(spacing: 10) {
            // Count Badge Pill
            HStack(spacing: 7) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(electricPurple)
                
                Text("\(savedManager.totalSavedCount) \(savedManager.totalSavedCount == 1 ? "Plot" : "Plots") Saved")
                    .font(.googleSans(size: 14, weight: .semibold))
                    .foregroundColor(primaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                colorScheme == .dark
                    ? Color(red: 116/255, green: 18/255, blue: 250/255).opacity(0.22)
                    : Color(red: 116/255, green: 18/255, blue: 250/255).opacity(0.10)
            )
            .clipShape(Capsule())
            
            Spacer()
            
            // Total Area Tally Pill
            HStack(spacing: 5) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(secondaryText)
                
                Text(savedManager.totalAreaAcresSummary)
                    .font(.googleSans(size: 13.5, weight: .medium))
                    .foregroundColor(secondaryText)
            }
        }
    }
    
    // MARK: - 4. Large Saved Land Card (With District Hero Photography)
    
    private func savedLandCard(record: SavedLandRecord) -> some View {
        Button {
            Theme.haptic(.medium)
            selectedRecordForDetail = record
        } label: {
            VStack(spacing: 0) {
                // ── A. DISTRICT HERO IMAGE HEADER (150pt Height) ──
                ZStack(alignment: .bottomLeading) {
                    GeometryReader { geo in
                        Image(districtHeroImage(for: record.districtName))
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: 150)
                            .clipped()
                    }
                    .frame(height: 150)
                    
                    // Dark Aesthetic Gradient Overlay
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.15),
                            Color.black.opacity(0.40),
                            Color.black.opacity(0.85)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    
                    // Header Overlay Content
                    VStack(alignment: .leading, spacing: 0) {
                        // Top Bar inside Photo: Land Classification Badge (Left) & Bookmark Button (Right)
                        HStack(alignment: .top) {
                            if let landType = record.landType, !landType.isEmpty {
                                Text(landType)
                                    .font(.googleSans(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.35), lineWidth: 0.8)
                                    )
                            }
                            
                            Spacer()
                            
                            // Bookmark Delete Action Button
                            Button {
                                Theme.haptic(.light)
                                recordToDelete = record
                                showDeleteConfirmation = true
                            } label: {
                                Image(systemName: "bookmark.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 38, height: 38)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.35), lineWidth: 0.8)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        
                        Spacer()
                        
                        // Bottom Titles inside Photo: Village & District
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.villageName)
                                .font(.googleSans(size: 23, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .shadow(color: .black.opacity(0.5), radius: 4, y: 1)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.85))
                                
                                Text("\(record.tahasilName), \(record.districtName)")
                                    .font(.googleSans(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.90))
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 14)
                    }
                }
                .frame(height: 150)
                
                // ── B. CARD BODY: BOLD PLOT IDENTITY & RECORD DETAILS ──
                VStack(alignment: .leading, spacing: 16) {
                    // Primary Numbers Row: Big Plot No (Left) | Big Khata No (Right)
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("PLOT NUMBER")
                                .font(.googleSans(size: 11, weight: .bold))
                                .foregroundColor(secondaryText)
                                .tracking(0.8)
                            
                            Text("Plot \(record.plotNumber)")
                                .font(.googleSans(size: 28, weight: .bold))
                                .foregroundColor(primaryText)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("KHATIAN / KHATA")
                                .font(.googleSans(size: 11, weight: .bold))
                                .foregroundColor(secondaryText)
                                .tracking(0.8)
                            
                            Text("Khata \(record.khatianNumber)")
                                .font(.googleSans(size: 20, weight: .bold))
                                .foregroundColor(primaryText)
                        }
                    }
                    
                    Divider()
                        .overlay(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                    
                    // Area & Ownership Highlights
                    HStack(spacing: 12) {
                        // Area Pill
                        if let area = record.area, !area.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "ruler.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(red: 20/255, green: 130/255, blue: 70/255))
                                
                                Text(area)
                                    .font(.googleSans(size: 15, weight: .bold))
                                    .foregroundColor(Color(red: 20/255, green: 130/255, blue: 70/255))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                colorScheme == .dark
                                    ? Color(red: 20/255, green: 130/255, blue: 70/255).opacity(0.20)
                                    : Color(red: 220/255, green: 245/255, blue: 230/255)
                            )
                            .clipShape(Capsule())
                        }
                        
                        // Owner Summary
                        if !record.owners.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(secondaryText)
                                
                                Text(record.owners.first ?? "")
                                    .font(.googleSans(size: 14.5, weight: .medium))
                                    .foregroundColor(primaryText)
                                    .lineLimit(1)
                                
                                if record.owners.count > 1 {
                                    Text("+\(record.owners.count - 1)")
                                        .font(.googleSans(size: 12, weight: .bold))
                                        .foregroundColor(secondaryText)
                                }
                            }
                        }
                        
                        Spacer()
                    }
                    
                    // ── C. OPEN LAND PASSPORT ACTION CAPSULE ──
                    HStack {
                        Text("View Official Land Passport")
                            .font(.googleSans(size: 15.5, weight: .semibold))
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(colorScheme == .dark ? Color(red: 17/255, green: 24/255, blue: 39/255) : .white)
                    .padding(.horizontal, 18)
                    .frame(height: 48)
                    .background(
                        colorScheme == .dark
                            ? Color(red: 240/255, green: 242/255, blue: 245/255)
                            : Color(red: 24/255, green: 25/255, blue: 28/255),
                        in: Capsule()
                    )
                    .clipShape(Capsule())
                    .padding(.top, 4)
                }
                .padding(20)
                .background(cardBackground)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08),
                        lineWidth: 1.2
                    )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08),
                radius: 12,
                x: 0,
                y: 5
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 5. Large Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(
                        colorScheme == .dark
                            ? Color(red: 116/255, green: 18/255, blue: 250/255).opacity(0.22)
                            : Color(red: 116/255, green: 18/255, blue: 250/255).opacity(0.10)
                    )
                    .frame(width: 110, height: 110)
                
                Image(systemName: "bookmark")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(electricPurple)
            }
            
            VStack(spacing: 8) {
                Text("No Saved Lands Yet")
                    .font(.googleSans(size: 24, weight: .bold))
                    .foregroundColor(primaryText)
                
                Text("Tap the bookmark button on any parcel details or cadastral map plot to store official land records securely on your device for instant offline access.")
                    .font(.googleSans(size: 15.5, weight: .regular))
                    .foregroundColor(secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
    }
    
    // MARK: - 6. No Search Results
    
    private var noSearchResultsView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(secondaryText)
            
            Text("No plots match \"\(searchText)\"")
                .font(.googleSans(size: 18, weight: .semibold))
                .foregroundColor(primaryText)
            
            Text("Try searching with a plot number, khata number, village, or owner name.")
                .font(.googleSans(size: 14.5, weight: .regular))
                .foregroundColor(secondaryText)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - District Hero Image Resolver (Matching 30 Odisha Districts)
    
    private func districtHeroImage(for district: String) -> String {
        let name = district.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if name.contains("bhadrak") { return "DistrictHero_Bhadrak" }
        if name.contains("bargarh") { return "DistrictHero_Bargarh" }
        if name.contains("mayurbhanj") || name.contains("baripada") { return "DistrictHero_Mayurbhanj" }
        if name.contains("keonjhar") || name.contains("kendujhar") { return "DistrictHero_Kendujhar" }
        if name.contains("cuttack") { return "DistrictHero_Cuttack" }
        if name.contains("puri") { return "DistrictHero_Puri" }
        if name.contains("khordha") || name.contains("khurda") || name.contains("bhubaneswar") { return "DistrictHero_Khordha" }
        if name.contains("balasore") || name.contains("baleswar") { return "DistrictHero_Balasore" }
        if name.contains("sambalpur") { return "DistrictHero_Sambalpur" }
        if name.contains("koraput") { return "DistrictHero_Koraput" }
        if name.contains("ganjam") || name.contains("berhampur") { return "DistrictHero_Ganjam" }
        if name.contains("kalahandi") { return "DistrictHero_Kalahandi" }
        if name.contains("balangir") || name.contains("bolangir") { return "DistrictHero_Balangir" }
        if name.contains("dhenkanal") { return "DistrictHero_Dhenkanal" }
        if name.contains("angul") { return "DistrictHero_Angul" }
        if name.contains("sundargarh") || name.contains("sundergarh") || name.contains("rourkela") { return "DistrictHero_Sundargarh" }
        if name.contains("jajpur") { return "DistrictHero_Jajpur" }
        if name.contains("kendrapara") { return "DistrictHero_Kendrapara" }
        if name.contains("jagatsinghpur") { return "DistrictHero_Jagatsinghpur" }
        if name.contains("kandhamal") || name.contains("phulbani") { return "DistrictHero_Kandhamal" }
        if name.contains("rayagada") { return "DistrictHero_Rayagada" }
        if name.contains("malkangiri") { return "DistrictHero_Malkangiri" }
        if name.contains("nabarangpur") || name.contains("nowrangpur") { return "DistrictHero_Nabarangpur" }
        if name.contains("nayagarh") { return "DistrictHero_Nayagarh" }
        if name.contains("nuapada") { return "DistrictHero_Nuapada" }
        if name.contains("subarnapur") || name.contains("sonepur") { return "DistrictHero_Subarnapur" }
        if name.contains("deogarh") || name.contains("debagarh") { return "DistrictHero_Deogarh" }
        if name.contains("jharsuguda") { return "DistrictHero_Jharsuguda" }
        if name.contains("boudh") { return "DistrictHero_Boudh" }
        if name.contains("gajapati") { return "DistrictHero_Gajapati" }
        return "LandDetailsHeroBackground"
    }
}

#Preview {
    SavedLandsView()
}
