//
//  HomeScreenView.swift
//  MyBhoomi
//
//  Figma Pixel-Perfect Implementation of HomeScreen (Node ID: 772:452)
//

import SwiftUI

public struct DistrictItem: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let odiaName: String
    public let imageName: String
    public let gradientStart: Color
    public let gradientEnd: Color
    
    public init(
        id: String,
        name: String,
        odiaName: String,
        imageName: String,
        gradientStart: Color,
        gradientEnd: Color
    ) {
        self.id = id
        self.name = name
        self.odiaName = odiaName
        self.imageName = imageName
        self.gradientStart = gradientStart
        self.gradientEnd = gradientEnd
    }
}

public struct HomeScreenView: View {
    @ObservedObject public var viewModel: MapViewModel
    @Binding public var selectedTab: AppTab
    @Binding public var showSubscription: Bool
    
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    
    // Master List of 30 Districts of Odisha matching Figma visual cards
    private let allDistricts: [DistrictItem] = [
        DistrictItem(id: "1", name: "Anugul", odiaName: "ଅନୁଗୋଳ", imageName: "district_anugul", gradientStart: Color(red: 255/255, green: 225/255, blue: 0/255, opacity: 0.7), gradientEnd: Color(red: 253/255, green: 239/255, blue: 156/255, opacity: 0.7)),
        DistrictItem(id: "2", name: "Baleswar", odiaName: "ବାଲେଶ୍ୱର", imageName: "district_baleswar", gradientStart: Color(red: 255/255, green: 112/255, blue: 99/255, opacity: 0.7), gradientEnd: Color(red: 255/255, green: 13/255, blue: 0/255, opacity: 0.7)),
        DistrictItem(id: "3", name: "Baragarh", odiaName: "ବରଗଡ଼", imageName: "district_baragarh", gradientStart: Color(red: 255/255, green: 255/255, blue: 255/255, opacity: 0.7), gradientEnd: Color(red: 156/255, green: 86/255, blue: 255/255, opacity: 0.7)),
        DistrictItem(id: "4", name: "Bhadrak", odiaName: "ଭଦ୍ରକ", imageName: "district_bhadrak", gradientStart: Color(red: 255/255, green: 60/255, blue: 0/255, opacity: 0.7), gradientEnd: Color(red: 0/255, green: 255/255, blue: 166/255, opacity: 0.7)),
        DistrictItem(id: "5", name: "Bolangir", odiaName: "ବଲାଙ୍ଗୀର", imageName: "district_bolangir", gradientStart: Color(red: 255/255, green: 247/255, blue: 178/255, opacity: 0.7), gradientEnd: Color(red: 255/255, green: 251/255, blue: 0/255, opacity: 0.7)),
        DistrictItem(id: "6", name: "Boudh", odiaName: "ବୌଦ୍ଧ", imageName: "district_boudh", gradientStart: Color(red: 255/255, green: 247/255, blue: 174/255, opacity: 0.7), gradientEnd: Color(red: 255/255, green: 251/255, blue: 0/255, opacity: 0.7)),
        DistrictItem(id: "7", name: "Cuttack", odiaName: "କଟକ", imageName: "district_cuttack", gradientStart: Color(red: 255/255, green: 168/255, blue: 106/255, opacity: 0.7), gradientEnd: Color(red: 184/255, green: 181/255, blue: 0/255, opacity: 0.7)),
        DistrictItem(id: "8", name: "Deogarh", odiaName: "ଦେବଗଡ଼", imageName: "district_deogarh", gradientStart: Color(red: 255/255, green: 174/255, blue: 199/255, opacity: 0.0), gradientEnd: Color(red: 255/255, green: 0/255, blue: 30/255, opacity: 0.8)),
        DistrictItem(id: "9", name: "Dhenkanal", odiaName: "ଢେଙ୍କାନାଳ", imageName: "district_dhenkanal", gradientStart: Color(red: 159/255, green: 255/255, blue: 247/255, opacity: 0.7), gradientEnd: Color(red: 219/255, green: 186/255, blue: 0/255, opacity: 0.7)),
        DistrictItem(id: "10", name: "Ganjam", odiaName: "ଗଞ୍ଜାମ", imageName: "district_ganjam", gradientStart: Color(red: 187/255, green: 244/255, blue: 255/255, opacity: 0.7), gradientEnd: Color(red: 0/255, green: 119/255, blue: 255/255, opacity: 0.7)),
        DistrictItem(id: "11", name: "Jagatsinghpur", odiaName: "ଜଗତସିଂହପୁର", imageName: "district_jagatsinghpur", gradientStart: Color(red: 187/255, green: 244/255, blue: 255/255, opacity: 0.7), gradientEnd: Color(red: 255/255, green: 102/255, blue: 0/255, opacity: 0.7)),
        DistrictItem(id: "12", name: "Jajpur", odiaName: "ଯାଜପୁର", imageName: "district_jajpur", gradientStart: Color(red: 253/255, green: 215/255, blue: 254/255, opacity: 0.7), gradientEnd: Color(red: 219/255, green: 215/255, blue: 0/255, opacity: 0.7)),
        DistrictItem(id: "13", name: "Jharsuguda", odiaName: "ଝାରସୁଗୁଡ଼ା", imageName: "district_jharsuguda", gradientStart: Color(red: 253/255, green: 215/255, blue: 254/255, opacity: 0.7), gradientEnd: Color(red: 0/255, green: 219/255, blue: 29/255, opacity: 0.7)),
        DistrictItem(id: "14", name: "Kalahandi", odiaName: "କଳାହାଣ୍ଡି", imageName: "district_kalahandi", gradientStart: Color(red: 253/255, green: 215/255, blue: 254/255, opacity: 0.7), gradientEnd: Color(red: 0/255, green: 219/255, blue: 29/255, opacity: 0.7)),
        DistrictItem(id: "15", name: "Kandhamal", odiaName: "କନ୍ଧମାଳ", imageName: "district_kandhamal", gradientStart: Color(red: 255/255, green: 255/255, blue: 255/255, opacity: 0.7), gradientEnd: Color(red: 255/255, green: 4/255, blue: 8/255, opacity: 0.7)),
        DistrictItem(id: "16", name: "Kendrapada", odiaName: "କେନ୍ଦ୍ରାପଡ଼ା", imageName: "district_kendrapada", gradientStart: Color(red: 255/255, green: 244/255, blue: 244/255, opacity: 0.7), gradientEnd: Color(red: 175/255, green: 0/255, blue: 35/255, opacity: 0.7)),
        DistrictItem(id: "17", name: "Kendujhar", odiaName: "କେନ୍ଦୁଝର", imageName: "district_kendujhar", gradientStart: Color(red: 255/255, green: 153/255, blue: 153/255, opacity: 0.7), gradientEnd: Color(red: 219/255, green: 106/255, blue: 0/255, opacity: 0.7)),
        DistrictItem(id: "18", name: "Khurda", odiaName: "ଖୋର୍ଦ୍ଧା", imageName: "district_khurda", gradientStart: Color(red: 255/255, green: 153/255, blue: 153/255, opacity: 0.7), gradientEnd: Color(red: 219/255, green: 106/255, blue: 0/255, opacity: 0.7)),
        DistrictItem(id: "19", name: "Koraput", odiaName: "କୋରାପୁଟ", imageName: "district_koraput", gradientStart: Color(red: 255/255, green: 224/255, blue: 224/255, opacity: 0.7), gradientEnd: Color(red: 255/255, green: 0/255, blue: 0/255, opacity: 0.7)),
        DistrictItem(id: "20", name: "Malkangiri", odiaName: "ମାଲକାନଗିରି", imageName: "district_malkangiri", gradientStart: Color(red: 237/255, green: 221/255, blue: 255/255, opacity: 0.7), gradientEnd: Color(red: 118/255, green: 0/255, blue: 255/255, opacity: 0.7)),
        DistrictItem(id: "21", name: "Mayurbhanj", odiaName: "ମୟୂରଭଞ୍ଜ", imageName: "district_mayurbhanj", gradientStart: Color(red: 255/255, green: 255/255, blue: 255/255, opacity: 0.7), gradientEnd: Color(red: 0/255, green: 153/255, blue: 255/255, opacity: 0.7)),
        DistrictItem(id: "22", name: "Nabarangpur", odiaName: "ନବରଙ୍ଗପୁର", imageName: "district_nabarangpur", gradientStart: Color(red: 255/255, green: 153/255, blue: 153/255, opacity: 0.7), gradientEnd: Color(red: 219/255, green: 106/255, blue: 0/255, opacity: 0.7)),
        DistrictItem(id: "23", name: "Nayagarh", odiaName: "ନୟାଗଡ଼", imageName: "district_nayagarh", gradientStart: Color(red: 255/255, green: 153/255, blue: 153/255, opacity: 0.7), gradientEnd: Color(red: 219/255, green: 106/255, blue: 0/255, opacity: 0.7)),
        DistrictItem(id: "24", name: "Nuapada", odiaName: "ନୂଆପଡ଼ା", imageName: "district_nuapada", gradientStart: Color(red: 255/255, green: 255/255, blue: 255/255, opacity: 0.7), gradientEnd: Color(red: 161/255, green: 255/255, blue: 0/255, opacity: 0.7)),
        DistrictItem(id: "25", name: "Puri", odiaName: "ପୁରୀ", imageName: "district_puri", gradientStart: Color(red: 255/255, green: 222/255, blue: 222/255, opacity: 0.7), gradientEnd: Color(red: 219/255, green: 106/255, blue: 0/255, opacity: 0.7)),
        DistrictItem(id: "26", name: "Rayagada", odiaName: "ରାୟଗଡ଼ା", imageName: "district_rayagada", gradientStart: Color(red: 255/255, green: 153/255, blue: 153/255, opacity: 0.7), gradientEnd: Color(red: 219/255, green: 106/255, blue: 0/255, opacity: 0.7)),
        DistrictItem(id: "27", name: "Sambalpur", odiaName: "ସମ୍ବଲପୁର", imageName: "district_sambalpur", gradientStart: Color(red: 255/255, green: 255/255, blue: 255/255, opacity: 0.7), gradientEnd: Color(red: 119/255, green: 0/255, blue: 255/255, opacity: 0.7)),
        DistrictItem(id: "28", name: "Sonepur", odiaName: "ସୋନପୁର", imageName: "district_sonepur", gradientStart: Color(red: 255/255, green: 222/255, blue: 222/255, opacity: 0.7), gradientEnd: Color(red: 219/255, green: 142/255, blue: 0/255, opacity: 0.7)),
        DistrictItem(id: "29", name: "Sundargarh", odiaName: "ସୁନ୍ଦରଗଡ଼", imageName: "district_sundargarh", gradientStart: Color(red: 255/255, green: 153/255, blue: 153/255, opacity: 0.7), gradientEnd: Color(red: 219/255, green: 106/255, blue: 0/255, opacity: 0.7))
    ]
    
    private var filteredDistricts: [DistrictItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty {
            return allDistricts
        }
        return allDistricts.filter {
            $0.name.lowercased().contains(q) || $0.odiaName.contains(q)
        }
    }
    
    private let columns = [
        GridItem(.fixed(109.33), spacing: 10),
        GridItem(.fixed(109.33), spacing: 10),
        GridItem(.fixed(109.33), spacing: 10)
    ]
    
    public init(
        viewModel: MapViewModel,
        selectedTab: Binding<AppTab>,
        showSubscription: Binding<Bool>
    ) {
        self.viewModel = viewModel
        self._selectedTab = selectedTab
        self._showSubscription = showSubscription
    }
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            // Full-screen Canvas Background Gradient (Figma #781:2223)
            LinearGradient(
                stops: [
                    .init(color: Color(hex: "#FDFCFF"), location: 0.01),
                    .init(color: Color(hex: "#E7D5FD"), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Sticky Header Section (Branding Logo, Credits Capsule, Search Bar & Section Title)
                VStack(spacing: 0) {
                    topHeaderRow
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 14)
                    
                    searchBarView
                        .padding(.horizontal, 18)
                        .padding(.bottom, 14)
                    
                    HStack {
                        Text("Select a district")
                            .font(.stackSansHeadline(size: 16.7, weight: .regular))
                            .foregroundColor(Color(hex: "#6C6C6C"))
                        Spacer()
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 10)
                }
                
                // Only the District Cards Grid is scrollable
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(filteredDistricts) { district in
                            districtCard(district)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
                    .padding(.bottom, isSearchFocused ? 30 : 100)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            
            // Floating Bottom Dock Navigation (Hidden when searching to prevent floating above keyboard)
            if !isSearchFocused {
                FloatingDockBar(selectedTab: $selectedTab)
                    .padding(.bottom, 0)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isSearchFocused)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
    
    // MARK: - Top Header Row (Branding + Credit Capsule)
    private var topHeaderRow: some View {
        HStack(alignment: .center) {
            // App Branding "prettyplot" Official Image Logo (Prominent size aligned with credit pill)
            Image("PreetyplotLogo")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(height: 48)
            
            Spacer()
            
            // Plot Search Credits Pill (Custom SVG Flame + SF Pro Rounded Medium + Crisp White Pill)
            PlotSearchCreditButton(
                credits: subscriptionManager.remainingPlotCredits,
                isUnlimited: subscriptionManager.isUnlimited,
                isCoverPresented: showSubscription
            ) {
                showSubscription = true
            }
            .frame(height: 48)
        }
        .frame(height: 48)
    }
    
    // MARK: - Search Bar View (Figma #772:465 - Border Only, No Solid Fill)
    private var searchBarView: some View {
        HStack(spacing: 8) {
            TextField("Search for your district", text: $searchText)
                .font(.stackSansHeadline(size: 19.35, weight: .regular))
                .foregroundColor(Color(hex: "#202020"))
                .focused($isSearchFocused)
                .submitLabel(.search)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Color(hex: "#9E9E9E"))
                }
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 19.56, weight: .regular))
                    .foregroundColor(Color(hex: "#747474"))
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 50.37)
        .background(
            RoundedRectangle(cornerRadius: 25.18)
                .stroke(isSearchFocused ? Color(hex: "#7600FF").opacity(0.4) : Color(hex: "#E5E5E5"), lineWidth: 1.5)
        )
    }
    
    // MARK: - District Visual Card (Figma Exact 109.33 x 119.21 pt, radius 4px)
    private func districtCard(_ district: DistrictItem) -> some View {
        Button {
            selectDistrict(district)
        } label: {
            ZStack(alignment: .bottom) {
                // District Scenic Photo
                Image(district.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 109.33, height: 119.21)
                    .clipped()
                
                // Vibrant Gradient Tint Overlay
                LinearGradient(
                    colors: [district.gradientStart, district.gradientEnd],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: 109.33, height: 119.21)
                
                // Bottom Semi-Transparent Dark Bar (Figma #772:470: rgba(0,0,0,0.34), height 30.56, radius 0 0 4 4)
                Rectangle()
                    .fill(Color.black.opacity(0.34))
                    .frame(width: 109.33, height: 30.56)
                    .overlay(
                        // District Name (#772:471: Stack Sans Headline Light in Pure White 18.55pt, Centered)
                        Text(district.name)
                            .font(.stackSansHeadline(size: 18.55, weight: .light))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    )
            }
            .frame(width: 109.33, height: 119.21)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(BhumitraCardButtonStyle())
    }
    
    // MARK: - Selection Handler
    private func selectDistrict(_ district: DistrictItem) {
        AnalyticsService.shared.log(.landSearchStarted(
            searchMethod: .dropdownManual,
            districtID: district.name,
            tehsilID: ""
        ))
        
        let targetCoord = coordinateForDistrict(district.name)
        viewModel.mapCenter = targetCoord
        viewModel.zoomLevel = 13.5
        viewModel.pendingDistrictSelectionName = district.name
        viewModel.shouldOpenLocationPicker = true
        
        // Switch to the Cadastral Map tab
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            selectedTab = .map
        }
    }
    
    private func coordinateForDistrict(_ name: String) -> Coordinate {
        let n = name.lowercased()
        if n.contains("anugul") || n.contains("angul") { return Coordinate(latitude: 20.8394, longitude: 85.1014) }
        if n.contains("baleswar") || n.contains("balasore") { return Coordinate(latitude: 21.4934, longitude: 86.9135) }
        if n.contains("baragarh") || n.contains("bargarh") { return Coordinate(latitude: 21.3340, longitude: 83.6214) }
        if n.contains("bhadrak") { return Coordinate(latitude: 21.0543, longitude: 86.4969) }
        if n.contains("bolangir") { return Coordinate(latitude: 20.7107, longitude: 83.4842) }
        if n.contains("boudh") { return Coordinate(latitude: 20.8378, longitude: 84.3267) }
        if n.contains("cuttack") { return Coordinate(latitude: 20.4625, longitude: 85.8828) }
        if n.contains("deogarh") { return Coordinate(latitude: 21.5367, longitude: 84.7339) }
        if n.contains("dhenkanal") { return Coordinate(latitude: 20.6582, longitude: 85.5969) }
        if n.contains("ganjam") { return Coordinate(latitude: 19.3150, longitude: 84.7941) }
        if n.contains("jagatsingh") { return Coordinate(latitude: 20.2587, longitude: 86.1687) }
        if n.contains("jajpur") { return Coordinate(latitude: 20.8504, longitude: 86.3344) }
        if n.contains("jharsuguda") { return Coordinate(latitude: 21.8554, longitude: 84.0062) }
        if n.contains("kalahandi") { return Coordinate(latitude: 19.9075, longitude: 83.1659) }
        if n.contains("kandhamal") { return Coordinate(latitude: 20.4764, longitude: 84.2343) }
        if n.contains("kendra") { return Coordinate(latitude: 20.4984, longitude: 86.4230) }
        if n.contains("kendujhar") || n.contains("keonjhar") { return Coordinate(latitude: 21.6289, longitude: 85.5817) }
        if n.contains("khurda") || n.contains("khordha") { return Coordinate(latitude: 20.2961, longitude: 85.8245) }
        if n.contains("koraput") { return Coordinate(latitude: 18.8135, longitude: 82.7123) }
        if n.contains("malkangiri") { return Coordinate(latitude: 18.3436, longitude: 81.8845) }
        if n.contains("mayurbhanj") || n.contains("baripada") { return Coordinate(latitude: 21.9346, longitude: 86.7368) }
        if n.contains("nabarang") { return Coordinate(latitude: 19.2314, longitude: 82.5511) }
        if n.contains("nayagarh") { return Coordinate(latitude: 20.1259, longitude: 85.1065) }
        if n.contains("nuapada") { return Coordinate(latitude: 20.8354, longitude: 82.5292) }
        if n.contains("puri") { return Coordinate(latitude: 19.8135, longitude: 85.8312) }
        if n.contains("rayagada") { return Coordinate(latitude: 19.1717, longitude: 83.4163) }
        if n.contains("sambalpur") { return Coordinate(latitude: 21.4669, longitude: 83.9812) }
        if n.contains("sonepur") || n.contains("subarnapur") { return Coordinate(latitude: 20.8407, longitude: 83.9168) }
        if n.contains("sundargarh") || n.contains("rourkela") { return Coordinate(latitude: 22.2604, longitude: 84.8536) }
        return Coordinate(latitude: AppConfig.defaultLatitude, longitude: AppConfig.defaultLongitude)
    }
}
