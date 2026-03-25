import SwiftUI

// MARK: - Fuel the Freeway — Nutrition Dashboard
// Photo-to-Shard placeholder (AI vision hook); manual log; Congestion Alert + Movement Snack CTA.

struct NutritionDashboardView: View {
    @Bindable var viewModel: LabViewModel
    @State private var showManualLog: Bool = false
    @State private var showMovementSnack: Bool = false
    @State private var showMealScan: Bool = false
    @State private var lastLoggedShards: Int = 0
    @State private var showShardToast: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            headerBlock
            photoToShardCard
            if viewModel.hasCongestionAlert {
                congestionAlertCard
            }
            quickLogCard
            shardBreakdownCard
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .background(Theme.deepBlack)
        .sheet(isPresented: $showManualLog) {
            ManualMealLogSheet(viewModel: viewModel, lastLoggedShards: $lastLoggedShards, showShardToast: $showShardToast)
        }
        .sheet(isPresented: $showMovementSnack) {
            MovementSnackClearSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showMealScan) {
            MealScanSheet(
                viewModel: viewModel,
                lastLoggedShards: $lastLoggedShards,
                showShardToast: $showShardToast,
                onDismiss: { showMealScan = false },
                onLogManually: { showMealScan = false; showManualLog = true }
            )
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FUEL THE FREEWAY")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(3)
                .foregroundStyle(Theme.brandBlue)
            Text("High-grade fuel for the Bio-Electric Freeway and fascia. Log meals to earn shards.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 16)
    }

    private var photoToShardCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.brandCyan)
                Text("PHOTO TO SHARD")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Theme.brandCyan)
            }
            Text("Snap a photo of your meal. AI will identify macros and award shards for Structural Repair, Fascial Elasticity, and Signal Velocity.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)
            Button {
                if GeminiService.shared.isConfigured {
                    showMealScan = true
                } else {
                    showManualLog = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                    Text(GeminiService.shared.isConfigured ? "Scan meal (camera)" : "Scan meal (set API key) or log manually")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.brandBlue.opacity(0.2))
                .foregroundStyle(Theme.brandBlue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Scan meal with camera")
            .accessibilityHint(GeminiService.shared.isConfigured ? "Opens camera to scan meal" : "Gemini API key not set; opens manual log")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.brandBlue.opacity(0.2), lineWidth: 1))
        )
    }

    private var congestionAlertCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("CONGESTION ALERT")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.orange)
            }
            Text("Processed or inflammatory foods create a roadblock on the CNS Freeway. Do a Movement Snack to clear it and earn +5 shards.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)
            Button {
                showMovementSnack = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "figure.walk")
                    Text("Clear with Movement Snack")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.orange.opacity(0.2))
                .foregroundStyle(.orange)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clear congestion with movement snack")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.orange.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.orange.opacity(0.3), lineWidth: 1))
        )
    }

    private var quickLogCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("QUICK LOG")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.secondary)
            Button {
                showManualLog = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Theme.brandBlue)
                    Text("Log meal manually")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(16)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    private var shardBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SHARD REWARDS")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.secondary)
            VStack(spacing: 8) {
                shardRow(label: "Structural Repair (high protein/leucine)", shards: 5)
                shardRow(label: "Fascial Elasticity (collagen / vitamin C)", shards: 10)
                shardRow(label: "Signal Velocity (hydration / electrolytes)", shards: 5)
                shardRow(label: "Congestion cleared (Movement Snack)", shards: 5)
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func shardRow(label: String, shards: Int) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text("+\(shards)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.brandCyan)
        }
    }
}

// MARK: - Meal scan: camera/library → Gemini vision → parse → shards

private struct MealScanSheet: View {
    @Bindable var viewModel: LabViewModel
    @Binding var lastLoggedShards: Int
    @Binding var showShardToast: Bool
    var onDismiss: () -> Void
    var onLogManually: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedImage: UIImage?
    @State private var showImagePicker: Bool = false
    @State private var imagePickerSource: ImagePickerView.Source = .camera
    @State private var isAnalyzing: Bool = false
    @State private var errorMessage: String?
    @State private var scanResult: (shards: Int, structural: Bool, fascial: Bool, signal: Bool, inflammatory: Bool)?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let result = scanResult {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Theme.brandCyan)
                        Text("+\(result.shards) Shards")
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .foregroundStyle(Theme.brandCyan)
                        Text("Structural Repair: \(result.structural ? "✓" : "—") · Fascial: \(result.fascial ? "✓" : "—") · Signal: \(result.signal ? "✓" : "—")\(result.inflammatory ? " · Congestion" : "")")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 32)
                    Button("Done") {
                        lastLoggedShards = result.shards
                        showShardToast = true
                        onDismiss()
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.brandBlue)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 24)
                } else if isAnalyzing {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(Theme.brandBlue)
                            .scaleEffect(1.2)
                        Text("Analyzing meal...")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                } else {
                    if let err = errorMessage {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    VStack(spacing: 12) {
                        Button {
                            imagePickerSource = .camera
                            showImagePicker = true
                        } label: {
                            Label("Take photo", systemImage: "camera.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Theme.brandBlue.opacity(0.2))
                                .foregroundStyle(Theme.brandBlue)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        Button {
                            imagePickerSource = .photoLibrary
                            showImagePicker = true
                        } label: {
                            Label("Choose from library", systemImage: "photo.on.rectangle.angled")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.08))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        Button {
                            dismiss()
                            onLogManually()
                        } label: {
                            Text("Log manually instead")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.deepBlack)
            .navigationTitle("Scan meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                        dismiss()
                    }
                    .foregroundStyle(Theme.brandBlue)
                }
            }
            .fullScreenCover(isPresented: $showImagePicker) {
                ImagePickerView(source: imagePickerSource, image: $selectedImage, onDismiss: {
                    showImagePicker = false
                    if selectedImage != nil { analyzeImage() }
                })
                .ignoresSafeArea()
            }
        }
    }

    private func analyzeImage() {
        guard let image = selectedImage else { return }
        errorMessage = nil
        isAnalyzing = true
        Task { @MainActor in
            defer { isAnalyzing = false }
            do {
                let ai = try await FELFuelPhotoShardService.analyzeMealImage(image)
                if ai.inflammatoryDetected { viewModel.setCongestionAlert(true) }
                viewModel.applyMealLogRewards(
                    structuralRepair: ai.structuralRepair,
                    fascialElasticity: ai.fascialElasticity,
                    signalVelocity: ai.signalVelocity,
                    congestionCleared: false
                )
                let rewards = ShardReward.forMealLog(
                    structuralRepair: ai.structuralRepair,
                    fascialElasticity: ai.fascialElasticity,
                    signalVelocity: ai.signalVelocity,
                    hadCongestionCleared: false
                )
                let shards = rewards.reduce(0) { $0 + $1.amount }
                scanResult = (shards, ai.structuralRepair, ai.fascialElasticity, ai.signalVelocity, ai.inflammatoryDetected)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Manual meal log (fallback when no API key or user choice)

private struct ManualMealLogSheet: View {
    @Bindable var viewModel: LabViewModel
    @Binding var lastLoggedShards: Int
    @Binding var showShardToast: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var structuralRepair: Bool = true
    @State private var fascialElasticity: Bool = false
    @State private var signalVelocity: Bool = false
    @State private var isInflammatory: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Structural Repair (protein/leucine)", isOn: $structuralRepair)
                    Toggle("Fascial Elasticity (collagen / vitamin C)", isOn: $fascialElasticity)
                    Toggle("Signal Velocity (hydration)", isOn: $signalVelocity)
                    Toggle("Processed / inflammatory (triggers Congestion)", isOn: $isInflammatory)
                } header: {
                    Text("Meal nutrients")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.deepBlack)
            .navigationTitle("Log meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.brandBlue)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { submitLog() }
                        .foregroundStyle(Theme.brandBlue)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func submitLog() {
        if isInflammatory {
            viewModel.setCongestionAlert(true)
        }
        let congestionCleared = false
        viewModel.applyMealLogRewards(
            structuralRepair: structuralRepair,
            fascialElasticity: fascialElasticity,
            signalVelocity: signalVelocity,
            congestionCleared: congestionCleared
        )
        let rewards = ShardReward.forMealLog(
            structuralRepair: structuralRepair,
            fascialElasticity: fascialElasticity,
            signalVelocity: signalVelocity,
            hadCongestionCleared: congestionCleared
        )
        lastLoggedShards = rewards.reduce(0) { $0 + $1.amount }
        showShardToast = true
        dismiss()
    }
}

// MARK: - Movement Snack clear sheet (clears congestion, awards +5 shards)

private struct MovementSnackClearSheet: View {
    @Bindable var viewModel: LabViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.brandBlue)
                Text("Do a quick Movement Snack to clear the roadblock: 90/90 seated reset, hip flexor stretch, or a short walk.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button {
                    viewModel.clearCongestion()
                    viewModel.applyMealLogRewards(structuralRepair: false, fascialElasticity: false, signalVelocity: false, congestionCleared: true)
                    dismiss()
                } label: {
                    Text("I did a Movement Snack — Clear & +5 Shards")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.brandBlue)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)
            }
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
            .background(Theme.deepBlack)
            .navigationTitle("Clear Congestion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.brandBlue)
                }
            }
        }
    }
}
