import SwiftUI

struct DoorDashOrderBridgeView: View {
    @Environment(\.dismiss) private var dismiss
    let onLogged: () -> Void
    
    @StateObject private var service = BioFuelService.shared
    
    @State private var selectedIntent: String = ""
    @State private var maxCalories: String = ""
    @State private var minProtein: String = ""
    @State private var remainingCalories: Int = 2000
    @State private var remainingProtein: Int = 150
    
    @State private var searchResult: DoorDashSearchResult? = nil
    @State private var isLoading = false
    @State private var isLogging = false
    @State private var errorMessage: String? = nil
    
    let intents = [
        ("post_dunk_recovery", "Post-Dunk Recovery"),
        ("fascial_hydration", "Fascial Hydration"),
        ("cns_ignition", "CNS Ignition"),
        ("endurance_base", "Endurance Base"),
        ("sleep_anabolic", "Sleep Anabolic")
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.deepBlack.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header Status Bar
                    statusBanner
                        .padding(.horizontal)
                        .padding(.top, 12)
                    
                    // Filters Configuration Drawer
                    filterDrawer
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    // Main Feed
                    ScrollView {
                        VStack(spacing: 16) {
                            if isLoading {
                                loadingView
                            } else if let error = errorMessage {
                                errorView(error)
                            } else if let result = searchResult {
                                if result.matches.isEmpty {
                                    noMatchesView
                                } else {
                                    matchesList(result.matches)
                                }
                            } else {
                                loadingView
                            }
                        }
                        .padding(16)
                    }
                    
                    policyDisclaimer
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }
            }
            .navigationTitle("DOORDASH PERFORMANCE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.neonGreen)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .onAppear {
                loadInitialBudget()
            }
        }
    }
    
    private var statusBanner: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("REMAINING MACRO BUDGET")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.neonGreen)
                
                HStack(spacing: 12) {
                    Text("\(remainingCalories) KCAL")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    
                    Text("\(remainingProtein)G PRO")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(.red)
                }
            }
            Spacer()
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var filterDrawer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PERFORMANCE NUTRITION FILTERS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
            
            // Intent Selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(intents, id: \.0) { item in
                        Button {
                            selectedIntent = item.0
                            runSearch()
                        } label: {
                            Text(item.1.uppercased())
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selectedIntent == item.0 ? Theme.neonGreen : Color.white.opacity(0.05))
                                .foregroundStyle(selectedIntent == item.0 ? .black : .white)
                                .cornerRadius(6)
                        }
                    }
                }
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MAX KCAL")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    TextField("Max Calories", text: $maxCalories)
                        .keyboardType(.numberPad)
                        .font(.system(size: 13, design: .monospaced))
                        .padding(8)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(6)
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("MIN PROTEIN (G)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    TextField("Min Protein", text: $minProtein)
                        .keyboardType(.numberPad)
                        .font(.system(size: 13, design: .monospaced))
                        .padding(8)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(6)
                        .foregroundStyle(.white)
                }
                
                Button {
                    runSearch()
                } label: {
                    Text("APPLY")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Theme.neonGreen)
                        .foregroundStyle(.black)
                        .cornerRadius(6)
                }
                .padding(.top, 14)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
    }
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Theme.neonGreen)
            Text("PARSING AREA RESTAURANTS...")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.neonGreen)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }
    
    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.red)
            Text("API CONNECTION FAILED")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.red)
            Text(msg)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                runSearch()
            } label: {
                Text("RETRY SEARCH")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }
    
    private var noMatchesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("NO MATCHES IN YOUR AREA")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
            Text("Adjust calorie/protein filters to widen search scope.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private func matchesList(_ items: [DoorDashMatch]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TAILORED RE-FUEL OPTIMIZATIONS")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
            
            ForEach(items) { match in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(match.restaurant.uppercased())
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(Theme.neonGreen)
                            
                            Text(match.name)
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(.white)
                            
                            Text(String(format: "Est. Price: $%.2f", match.price_approx_usd))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        
                        // Custom performance intent badge
                        Text(match.intent.replacingOccurrences(of: "_", with: " ").uppercased())
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Theme.neonGreen.opacity(0.15))
                            .foregroundStyle(Theme.neonGreen)
                            .cornerRadius(4)
                    }
                    
                    // Macros strip
                    HStack(spacing: 12) {
                        macroSubCell(label: "KCAL", val: "\(match.macros.calories)", color: .white)
                        macroSubCell(label: "PRO", val: "\(match.macros.protein_g)g", color: .red)
                        macroSubCell(label: "CARB", val: "\(match.macros.carbs_g)g", color: .orange)
                        macroSubCell(label: "FAT", val: "\(match.macros.fats_g)g", color: Theme.brandBlue)
                    }
                    .padding(.vertical, 4)
                    
                    HStack(spacing: 8) {
                        // Order Link
                        Button {
                            openDoorDashLink(match.deep_link)
                        } label: {
                            HStack {
                                Image(systemName: "arrow.up.forward.app.fill")
                                Text("ORDER")
                            }
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .foregroundStyle(.white)
                            .cornerRadius(6)
                        }
                        
                        // Manual Log check
                        Button {
                            logMealDirectly(match)
                        } label: {
                            HStack {
                                if isLogging {
                                    ProgressView()
                                        .tint(.black)
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                }
                                Text("LOG METRICS")
                            }
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(Theme.neonGreen)
                            .foregroundStyle(.black)
                            .cornerRadius(6)
                        }
                        .disabled(isLogging)
                    }
                }
                .padding()
                .background(Theme.slateCard)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
            }
        }
    }
    
    private func macroSubCell(label: String, val: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(val)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.white.opacity(0.04))
        .cornerRadius(4)
    }
    
    private var policyDisclaimer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("APP STORE COMPLIANCE STATEMENT")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
            Text("DoorDash food deliveries process real-world items external to this digital ecosystem. As per Guideline 3.1.1, these ordering portals remain separated from digital token or progression loops. Awarded nutrition shards accrue solely through tracking inputs, scanning verifications, and manual metric registrations.")
                .font(.system(size: 8))
                .foregroundStyle(.secondary.opacity(0.7))
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(8)
    }
    
    // MARK: - Actions
    
    private func loadInitialBudget() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let today = try await service.getTodayProgress()
                await MainActor.run {
                    self.remainingCalories = max(0, today.remaining.calories)
                    self.remainingProtein = max(0, today.remaining.protein_g)
                    self.selectedIntent = today.intent
                    self.maxCalories = "\(self.remainingCalories)"
                    self.minProtein = "\(self.remainingProtein)"
                    self.isLoading = false
                    runSearch()
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func runSearch() {
        isLoading = true
        errorMessage = nil
        
        let cFilter = Int(maxCalories) ?? remainingCalories
        let pFilter = Int(minProtein) ?? remainingProtein
        
        Task {
            do {
                let result = try await service.doordashSearch(
                    intent: selectedIntent,
                    maxCalories: cFilter,
                    minProtein: pFilter
                )
                await MainActor.run {
                    self.searchResult = result
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func openDoorDashLink(_ link: String) {
        guard let url = URL(string: link) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
    private func logMealDirectly(_ match: DoorDashMatch) {
        guard !isLogging else { return }
        isLogging = true
        errorMessage = nil
        
        Task {
            do {
                let res = try await service.logManualMeal(
                    label: match.name,
                    calories: match.macros.calories,
                    protein: match.macros.protein_g,
                    carbs: match.macros.carbs_g,
                    fats: match.macros.fats_g,
                    source: "doordash"
                )
                await MainActor.run {
                    isLogging = false
                    if res.ok {
                        FelToastCenter.shared.show("Successfully logged macros for \(match.name)!")
                        onLogged()
                        dismiss()
                    } else {
                        FelToastCenter.shared.show("Log deduped or rejected by server.", isError: true)
                    }
                }
            } catch {
                await MainActor.run {
                    isLogging = false
                    FelToastCenter.shared.show("Logging failed: \(error.localizedDescription)", isError: true)
                }
            }
        }
    }
}
