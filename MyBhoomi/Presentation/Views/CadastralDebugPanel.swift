import SwiftUI

#if DEBUG
public struct CadastralDebugPanel: View {
    @ObservedObject var viewModel: MapViewModel
    @State private var isCollapsed: Bool = false
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(viewModel.gisApiStatus == "Connected" ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text("4K GEO GIS DEBUG")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.primary)
                        .tracking(0.8)
                }
                Spacer()
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isCollapsed.toggle()
                    }
                }) {
                    Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }
            
            if !isCollapsed {
                Divider().background(Color.black.opacity(0.1))
                
                Group {
                    DebugRow(label: "Stage", value: viewModel.debugPipelineStage, color: stageColor(viewModel.debugPipelineStage))
                    DebugRow(label: "GIS API", value: viewModel.gisApiStatus, color: viewModel.gisApiStatus == "Connected" ? .green : .red)
                    DebugRow(label: "District", value: viewModel.debugDistrictName)
                    if !viewModel.debugTahasilName.isEmpty {
                        DebugRow(label: "Tahasil", value: viewModel.debugTahasilName)
                    }
                    if !viewModel.debugGPName.isEmpty {
                        DebugRow(label: "GP Code", value: viewModel.debugGPName)
                    }
                    DebugRow(label: "Village", value: viewModel.debugVillageName)
                    DebugRow(label: "Village ID", value: viewModel.debugVillageID)
                    DebugRow(label: "Extent", value: viewModel.debugExtentStatus)
                    DebugRow(label: "Parcels", value: "\(viewModel.debugParcelCount) (Decoded: \(viewModel.debugDecodedParcelCount))")
                    DebugRow(label: "Cache", value: viewModel.debugCacheStatus)
                    DebugRow(label: "Current Zoom", value: String(format: "%.1f", viewModel.zoomLevel))
                    
                    if !viewModel.debugFirstPlots.isEmpty {
                        DebugRow(label: "Plots", value: viewModel.debugFirstPlots.joined(separator: ", "))
                    }
                    if let plot = viewModel.debugSelectedPlot {
                        DebugRow(label: "Selected Plot", value: plot, color: .orange)
                    }
                    if let sid = viewModel.debugSelectedSourceID {
                        DebugRow(label: "Source Feat ID", value: sid, color: .orange)
                    }
                    if let gType = viewModel.debugGeometryType {
                        DebugRow(label: "Geometry", value: gType)
                    }
                    
                    DebugRow(label: "Map Center", value: String(format: "%.4f, %.4f", viewModel.mapCenter.latitude, viewModel.mapCenter.longitude))
                    DebugRow(label: "API Latency", value: String(format: "%.0f ms", viewModel.debugRequestDurationMs))
                    
                    if let error = viewModel.debugErrorMessage {
                        DebugRow(label: "Error", value: error, color: .red)
                    }
                }
                
                Divider().background(Color.black.opacity(0.1))
                
                // Debug Action Buttons
                VStack(spacing: 5) {
                    Button(action: {
                        viewModel.loadTestVillage()
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            Text("Load Test Village (G_Dimbo)")
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.purple)
                        .cornerRadius(8)
                    }
                    
                    Button(action: {
                        viewModel.zoomToTestPlot12_1()
                    }) {
                        HStack {
                            Image(systemName: "scope")
                            Text("Zoom to Plot 12/1")
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.08), radius: 8, y: 2)
        .frame(maxWidth: 260)
    }
    
    private func stageColor(_ stage: String) -> Color {
        if stage.contains("FAILED") || stage.contains("ERROR") {
            return .red
        } else if stage.contains("LOADED") || stage.contains("SELECTED") {
            return .green
        } else if stage.contains("LOADING") || stage.contains("FETCHING") {
            return .orange
        }
        return .primary
    }
    
    private func shortEndpoint(_ urlStr: String) -> String {
        if urlStr.contains("localhost") {
            return "localhost:8000"
        } else if urlStr.contains("run.app") {
            return "Cloud Run (Prod)"
        }
        return urlStr.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "")
    }
}

struct DebugRow: View {
    let label: String
    let value: String
    var color: Color = .primary
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .lineLimit(1)
        }
    }
}
#endif
