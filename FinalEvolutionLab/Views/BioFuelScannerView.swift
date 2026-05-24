import SwiftUI
import PhotosUI

struct BioFuelScannerView: View {
    @Environment(\.dismiss) var dismiss
    let onLogged: () -> Void
    
    @StateObject private var service = BioFuelService.shared
    
    @State private var selectedModel = "gemini-2.5-flash"
    @State private var hintText = ""
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var base64ImageString: String? = nil
    
    @State private var isScanning = false
    @State private var isConfirming = false
    @State private var scanResult: BioFuelScanResult? = nil
    @State private var confirmResult: BioFuelConfirmResult? = nil
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerView
                    
                    modelPickerSection
                    
                    imagePickerSection
                    
                    contextHintSection
                    
                    if let error = errorMessage {
                        errorBanner(error)
                    }
                    
                    if isScanning {
                        scanningPlaceholder
                    } else if let result = scanResult {
                        resultCard(result)
                    } else {
                        scanButton
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .background(Theme.slateBackground)
            .navigationTitle("Meal Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onChange(of: selectedItem) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        await MainActor.run {
                            self.selectedImage = uiImage
                            self.base64ImageString = compressAndBase64(uiImage)
                            self.scanResult = nil
                            self.confirmResult = nil
                            self.errorMessage = nil
                        }
                    }
                }
            }
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AI VISION MEAL SCANNER")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(Theme.neonGreen)
                .tracking(2)
            
            Text("Estimate Macros")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(.white)
            
            Text("Take or upload a meal photo to calculate calories and macros. Logging verified scans awards Nutri-Shards.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
    }
    
    private var modelPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SELECT ENGINE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                modelOptionButton(id: "gemini-2.5-flash", title: "Gemini 2.5 Flash", subtitle: "Fast & food-focused")
                modelOptionButton(id: "gpt-5.2", title: "GPT-5.2", subtitle: "Strongest reasoning")
            }
        }
    }
    
    private func modelOptionButton(id: String, title: String, subtitle: String) -> some View {
        Button {
            selectedModel = id
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(selectedModel == id ? Theme.neonGreen : .white)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selectedModel == id ? Theme.neonGreen.opacity(0.08) : Color.white.opacity(0.02))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selectedModel == id ? Theme.neonGreen : Theme.cardBorder, lineWidth: 1)
            )
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
    
    private var imagePickerSection: some View {
        VStack(spacing: 12) {
            if let img = selectedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .cornerRadius(12)
                    .padding(4)
                    .background(Theme.slateCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Theme.cardBorder, lineWidth: 1)
                    )
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("No image selected")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .background(Theme.slateCard)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundStyle(Theme.cardBorder)
                )
            }
            
            HStack(spacing: 8) {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    HStack {
                        Image(systemName: "photo.fill")
                        Text(selectedImage != nil ? "Replace Photo" : "Upload Photo")
                    }
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(Theme.slateCard)
                    .foregroundStyle(.white)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.cardBorder, lineWidth: 1)
                    )
                }
                
                #if targetEnvironment(simulator)
                Button {
                    simulateImage()
                } label: {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text("Mock Food")
                    }
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(Theme.slateCard)
                    .foregroundStyle(.orange)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.orange.opacity(0.3), lineWidth: 1)
                    )
                }
                #endif
            }
        }
    }
    
    private var contextHintSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OPTIONAL CONTEXT")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
            
            TextField("e.g. Grass-fed steak, post-workout lunch...", text: $hintText)
                .font(.system(size: 13))
                .padding(12)
                .background(Theme.slateCard)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
                .foregroundStyle(.white)
        }
    }
    
    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(msg)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.red)
            Spacer()
        }
        .padding(12)
        .background(Color.red.opacity(0.08))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var scanningPlaceholder: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Theme.neonGreen)
            Text("Scanning meal with \(selectedModel)...")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.neonGreen)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(Theme.slateCard)
        .cornerRadius(12)
    }
    
    private var scanButton: some View {
        Button {
            executeScan()
        } label: {
            Text("Scan Meal")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(base64ImageString == nil ? Theme.cardBorder : Theme.neonGreen)
                .foregroundStyle(base64ImageString == nil ? Color.secondary : Color.black)
                .cornerRadius(10)
        }
        .disabled(base64ImageString == nil)
    }
    
    private func resultCard(_ result: BioFuelScanResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(result.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("Confidence: \(result.confidence)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            
            Text(result.description)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            
            // Macros grid
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    resultMacroCell(label: "KCAL", value: "\(result.macros.calories)", color: Theme.neonGreen)
                    resultMacroCell(label: "PROT", value: "\(result.macros.protein_g)g", color: .red)
                    resultMacroCell(label: "CARB", value: "\(result.macros.carbs_g)g", color: .orange)
                    resultMacroCell(label: "FAT", value: "\(result.macros.fats_g)g", color: Theme.brandBlue)
                }
            }
            
            // Diet warnings / Violations
            if let warnings = result.allergy_diet_warnings, !warnings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .foregroundStyle(.yellow)
                        Text("DIETARY WARNINGS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.yellow)
                    }
                    ForEach(warnings, id: \.self) { warning in
                        Text("• \(warning)")
                            .font(.system(size: 11))
                            .foregroundStyle(.yellow.opacity(0.9))
                    }
                }
                .padding(10)
                .background(Color.yellow.opacity(0.08))
                .cornerRadius(8)
            }
            
            if result.pending_confirmation {
                VStack(spacing: 8) {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.orange)
                            .font(.system(size: 12))
                            .padding(.top, 2)
                        Text("Review this estimate carefully. Confirming logs this entry to today's macros and awards +\(result.nutri_shards_potential) Nutri-Shards.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    
                    Button {
                        confirmScan(id: result.scan_id)
                    } label: {
                        if isConfirming {
                            ProgressView()
                                .tint(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Theme.neonGreen)
                                .cornerRadius(8)
                        } else {
                            Text("Confirm & Log Meal")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(Theme.neonGreen)
                                .foregroundStyle(.black)
                                .cornerRadius(8)
                        }
                    }
                    .disabled(isConfirming)
                }
                .padding(.top, 8)
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.neonGreen)
                    Text("Logged! Nutri-Shards Awarded: +\(confirmResult?.nutri_shards_awarded ?? result.nutri_shards_potential)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.neonGreen)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Theme.neonGreen.opacity(0.08))
                .cornerRadius(8)
                
                Button("Done") {
                    dismiss()
                }
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Theme.slateCard)
                .foregroundStyle(.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
            }
        }
        .padding(16)
        .background(Theme.slateCard)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
    }
    
    private func resultMacroCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.02))
        .cornerRadius(8)
    }
    
    private func executeScan() {
        guard let base64 = base64ImageString else { return }
        isScanning = true
        errorMessage = nil
        scanResult = nil
        confirmResult = nil
        
        Task {
            do {
                let res = try await service.scanMeal(model: selectedModel, base64Image: base64, hint: hintText)
                await MainActor.run {
                    self.scanResult = res
                    self.isScanning = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isScanning = false
                }
            }
        }
    }
    
    private func confirmScan(id: String) {
        isConfirming = true
        errorMessage = nil
        
        Task {
            do {
                let res = try await service.confirmScan(scanId: id)
                await MainActor.run {
                    self.confirmResult = res
                    if let result = self.scanResult {
                        // Mark as no longer pending
                        self.scanResult = BioFuelScanResult(
                            scan_id: result.scan_id,
                            day: result.day,
                            source: result.source,
                            model_used: result.model_used,
                            title: result.title,
                            confidence: result.confidence,
                            macros: result.macros,
                            description: result.description,
                            pending_confirmation: false,
                            nutri_shards_potential: result.nutri_shards_potential,
                            allergy_diet_warnings: result.allergy_diet_warnings,
                            allergy_diet_violation: result.allergy_diet_violation
                        )
                    }
                    self.isConfirming = false
                    self.onLogged()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isConfirming = false
                }
            }
        }
    }
    
    private func compressAndBase64(_ image: UIImage) -> String? {
        let maxEdge: CGFloat = 1280
        var size = image.size
        if size.width > maxEdge || size.height > maxEdge {
            let scale = maxEdge / max(size.width, size.height)
            size = CGSize(width: size.width * scale, height: size.height * scale)
        }
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        
        guard let jpegData = resizedImage.jpegData(compressionQuality: 0.82) else {
            return nil
        }
        return jpegData.base64EncodedString()
    }
    
    #if targetEnvironment(simulator)
    private func simulateImage() {
        // Create a simple dummy food-like placeholder drawing to simulate photos
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 400), format: format)
        let simulatedImage = renderer.image { ctx in
            // Draw a plate-like circle
            ctx.cgContext.setFillColor(UIColor.darkGray.cgColor)
            ctx.cgContext.fillEllipse(in: CGRect(x: 20, y: 20, width: 360, height: 360))
            
            // Draw some food chunks (green, red, orange)
            ctx.cgContext.setFillColor(UIColor.red.cgColor)
            ctx.cgContext.fillEllipse(in: CGRect(x: 100, y: 100, width: 80, height: 80))
            
            ctx.cgContext.setFillColor(UIColor.orange.cgColor)
            ctx.cgContext.fillEllipse(in: CGRect(x: 200, y: 120, width: 90, height: 90))
            
            ctx.cgContext.setFillColor(UIColor.green.cgColor)
            ctx.cgContext.fillEllipse(in: CGRect(x: 150, y: 200, width: 100, height: 100))
        }
        
        self.selectedImage = simulatedImage
        self.base64ImageString = compressAndBase64(simulatedImage)
        self.scanResult = nil
        self.confirmResult = nil
        self.errorMessage = nil
    }
    #endif
}
