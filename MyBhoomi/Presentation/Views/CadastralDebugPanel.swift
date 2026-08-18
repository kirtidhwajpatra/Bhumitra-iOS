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
                    DebugRow(label: "GIS API", value: viewModel.gisApiStatus, color: viewModel.gisApiStatus == "Connected" ? .green : .red)
                    DebugRow(label: "Village", value: viewModel.debugVillageName)
                    DebugRow(label: "Village ID", value: viewModel.debugVillageID)
                    DebugRow(label: "Parcel Count", value: "\(viewModel.debugParcelCount)")
                    DebugRow(label: "Current Zoom", value: String(format: "%.1f", viewModel.zoomLevel))
                    
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
                }
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.08), radius: 8, y: 2)
        .frame(maxWidth: 240)
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
