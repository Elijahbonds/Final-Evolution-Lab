import SwiftUI

struct BioFuelDashboardView: View {
    let viewModel: LabViewModel
    @StateObject private var service = BioFuelService.shared
    
    @State private var todayData: BioFuelToday? = nil
    @State private var cues: [BioFuelCue] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    @State private var showScanner = false
    @State private var showCookbook = false
    @State private var showDoorDash = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isLoading && todayData == nil {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if let today = todayData {
                contentView(today)
            } else {
                loadingView
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.neonGreen.opacity(0.2), lineWidth: 1)
                )
        )
        .sheet(isPresented: $showScanner, onDismiss: { refreshData() }) {
            BioFuelScannerView(onLogged: { refreshData() })
        }
        .sheet(isPresented: $showCookbook) {
            CookbookView()
        }
        .sheet(isPresented: $showDoorDash, onDismiss: { refreshData() }) {
            DoorDashOrderBridgeView(onLogged: { refreshData() })
        }
        .onAppear {
            refreshData()
        }
    }
    
    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(Theme.neonGreen)
            Text("Loading Bio-Fuel Status...")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.neonGreen)
        }
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
    }
    
    private func errorView(_ msg: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BIO-FUEL OFFLINE")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(.red)
            Text(msg)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
            Button {
                refreshData()
            } label: {
                Text("RETRY")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func contentView(_ today: BioFuelToday) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            FELPreviewLabel(text: FELPremiumCopy.Preview.bioFuelStub)

            // Header: Title & Actions
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("FEL OS · BIO-FUEL · NASM-CNC")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.neonGreen)
                        .tracking(2)
                    
                    Text(today.intent_label.uppercased())
                        .font(.system(size: 18, weight: .black))
                        .italic()
                        .foregroundStyle(.white)
                    
                    if today.targets_confidence == "default_assumption", let note = today.assumption_note {
                        Text(note)
                            .font(.system(size: 9))
                            .foregroundStyle(.yellow.opacity(0.85))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                Spacer()
            }
            
            // Primary Action Stripe Buttons
            HStack(spacing: 8) {
                Button {
                    showScanner = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "camera.fill")
                        Text("Scan Meal")
                    }
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Theme.neonGreen)
                    .foregroundStyle(.black)
                    .cornerRadius(8)
                }
                
                Button {
                    showCookbook = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "fork.knife")
                        Text("3D Cookbook")
                    }
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Theme.cardBorder)
                    .foregroundStyle(Theme.neonGreen)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.neonGreen.opacity(0.4), lineWidth: 1)
                    )
                }
                
                Button {
                    showDoorDash = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "truck.box.fill")
                        Text("Delivery")
                    }
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Theme.cardBorder)
                    .foregroundStyle(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
            }
            
            // Macro Grid (4 Columns)
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    macroCell(label: "KCAL", got: today.consumed.calories, target: today.target.calories, pct: today.pct.calories, color: Theme.neonGreen)
                    macroCell(label: "PROT", got: today.consumed.protein_g, target: today.target.protein_g, pct: today.pct.protein_g, color: .red)
                    macroCell(label: "CARB", got: today.consumed.carbs_g, target: today.target.carbs_g, pct: today.pct.carbs_g, color: .orange)
                    macroCell(label: "FAT", got: today.consumed.fats_g, target: today.target.fats_g, pct: today.pct.fats_g, color: Theme.brandBlue)
                }
            }
            
            // AI Coach Neuro-Cues Section
            if !cues.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .background(Theme.neonGreen.opacity(0.15))
                        .padding(.vertical, 4)
                    
                    ForEach(cues.prefix(2)) { cue in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: mapCueIcon(cue.icon))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.neonGreen)
                                .padding(.top, 2)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cue.title)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Theme.neonGreen.opacity(0.9))
                                
                                Text(cue.message)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            
                            Spacer()
                        }
                    }
                }
            }
        }
    }
    
    private func macroCell(label: String, got: Int, target: Int, pct: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(pct)%")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
            }
            
            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 5)
                    
                    Capsule()
                        .fill(color)
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(pct) / 100.0)), height: 5)
                }
            }
            .frame(height: 5)
            
            Text("\(got)/\(target)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(8)
        .background(Color.white.opacity(0.02))
        .cornerRadius(6)
    }
    
    private func refreshData() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let today = try await service.getTodayProgress()
                let cueList = try await service.getNeuroCues()
                
                await MainActor.run {
                    self.todayData = today
                    self.cues = cueList.cues
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func mapCueIcon(_ name: String) -> String {
        switch name.lowercased() {
        case "beef": return "fork.knife"
        case "droplet": return "drop.fill"
        case "moon": return "moon.stars.fill"
        case "wind": return "wind"
        case "scale": return "scalemass.fill"
        case "sparkles": return "sparkles"
        case "soup": return "sofa.fill"
        default: return "sparkles"
        }
    }
}
