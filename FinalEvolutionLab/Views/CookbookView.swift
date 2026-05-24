import SwiftUI
import SceneKit

struct CookbookView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = BioFuelService.shared
    
    @State private var loading = true
    @State private var intents: [BioFuelIntent] = []
    @State private var selectedIntent: String? = nil
    @State private var recipes: [BioFuelRecipeSummary] = []
    @State private var errorMessage: String?
    
    @State private var selectedRecipeDetail: BioFuelRecipeDetail?
    @State private var loadingDetail = false
    @State private var checklistIngredients: Set<String> = []
    
    @State private var instacartResult: InstacartCartResult?
    @State private var loadingInstacart = false
    
    var body: some View {
        ZStack {
            Theme.deepBlack
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("NUTRITION SUITE")
                            .font(.system(.caption2, design: .monospaced, weight: .bold))
                            .foregroundStyle(Theme.brandCyan)
                            .tracking(2)
                        Text("BIO-FUEL COOKBOOK")
                            .font(.system(.title2, design: .monospaced, weight: .black))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Intent selector pills
                if !intents.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            Button {
                                selectedIntent = nil
                                Task { await loadRecipes() }
                            } label: {
                                Text("ALL INTENTS")
                                    .font(.system(.caption, design: .monospaced, weight: .bold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(selectedIntent == nil ? Theme.brandBlue.opacity(0.2) : Color.white.opacity(0.04))
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(selectedIntent == nil ? Theme.brandBlue : Theme.cardBorder, lineWidth: 1)
                                    )
                                    .foregroundStyle(selectedIntent == nil ? Theme.brandBlue : .white.opacity(0.6))
                            }
                            
                            ForEach(intents) { intent in
                                Button {
                                    selectedIntent = intent.id
                                    Task { await loadRecipes() }
                                } label: {
                                    Text(intent.label.uppercased())
                                        .font(.system(.caption, design: .monospaced, weight: .bold))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule()
                                                .fill(selectedIntent == intent.id ? Theme.brandBlue.opacity(0.2) : Color.white.opacity(0.04))
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(selectedIntent == intent.id ? Theme.brandBlue : Theme.cardBorder, lineWidth: 1)
                                        )
                                        .foregroundStyle(selectedIntent == intent.id ? Theme.brandBlue : .white.opacity(0.6))
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                if loading {
                    Spacer()
                    ProgressView()
                        .tint(Theme.brandCyan)
                    Text("FETCHING OPTIMIZED RECIPES...")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 8)
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title)
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("RETRY") {
                            Task { await loadInitialData() }
                        }
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Theme.brandCyan))
                    }
                    Spacer()
                } else if recipes.isEmpty {
                    Spacer()
                    Text("NO RECIPES MATCHING THIS INTENT.")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(recipes) { recipe in
                                RecipeCard(recipe: recipe) {
                                    Task { await loadRecipeDetail(recipe.id) }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .sheet(item: $selectedRecipeDetail) { detail in
            RecipeDetailView(detail: detail, isPresented: Binding(
                get: { selectedRecipeDetail != nil },
                set: { if !$0 { selectedRecipeDetail = nil } }
            ))
        }
        .onAppear {
            Task { await loadInitialData() }
        }
    }
    
    private func loadInitialData() async {
        loading = true
        errorMessage = nil
        do {
            let result = try await service.getRecipes(intent: nil)
            self.intents = result.intents
            self.recipes = result.recipes
            loading = false
        } catch {
            errorMessage = "Failed to load cookbook: \(error.localizedDescription)"
            loading = false
        }
    }
    
    private func loadRecipes() async {
        loading = true
        errorMessage = nil
        do {
            let result = try await service.getRecipes(intent: selectedIntent)
            self.recipes = result.recipes
            loading = false
        } catch {
            errorMessage = "Failed to filter recipes: \(error.localizedDescription)"
            loading = false
        }
    }
    
    private func loadRecipeDetail(_ id: String) async {
        loadingDetail = true
        do {
            let detail = try await service.getRecipeDetail(id: id)
            self.checklistIngredients.removeAll()
            self.instacartResult = nil
            self.selectedRecipeDetail = detail
            loadingDetail = false
        } catch {
            FelToastCenter.shared.show("Failed to load details: \(error.localizedDescription)", isError: true)
            loadingDetail = false
        }
    }
}

// MARK: - Recipe Card Component
private struct RecipeCard: View {
    let recipe: BioFuelRecipeSummary
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // 3D Ring preview
                ZStack {
                    Color.black.opacity(0.4)
                    Recipe3DVisualizer(colors: parsePalette(recipe.viz_palette))
                        .frame(width: 80, height: 80)
                }
                .frame(width: 85, height: 85)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(recipe.intent_label.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.brandCyan)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.brandCyan.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        
                        Spacer()
                        
                        Text("\(recipe.duration_min) MIN")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    
                    Text(recipe.title.uppercased())
                        .font(.system(.subheadline, design: .monospaced, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    Text(recipe.summary)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Simple Macro Badge Row
                    HStack(spacing: 8) {
                        MacroMiniBadge(label: "C", value: "\(recipe.macros.calories)k")
                        MacroMiniBadge(label: "P", value: "\(recipe.macros.protein_g)g")
                        MacroMiniBadge(label: "F", value: "\(recipe.macros.fats_g)g")
                    }
                }
            }
            .padding()
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Theme.cardBorder, lineWidth: 1)
            )
        }
    }
}

private struct MacroMiniBadge: View {
    let label: String
    let value: String
    var body: some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(Theme.brandBlue)
            Text(value)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Recipe Detail Sheet View
private struct RecipeDetailView: View {
    let detail: BioFuelRecipeDetail
    @Binding var isPresented: Bool
    
    @State private var checklistIngredients: Set<String> = []
    @State private var loadingInstacart = false
    @State private var instacartResult: InstacartCartResult?
    
    var body: some View {
        ZStack {
            Theme.deepBlack
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Drag handle indicator
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Title header
                        VStack(alignment: .leading, spacing: 4) {
                            Text(detail.intent_label.uppercased())
                                .font(.system(.caption, design: .monospaced, weight: .bold))
                                .foregroundStyle(Theme.brandCyan)
                                .tracking(2)
                            Text(detail.title.uppercased())
                                .font(.system(.title3, design: .monospaced, weight: .black))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal)
                        
                        // 3D Visualizer Scene
                        ZStack(alignment: .bottomTrailing) {
                            Recipe3DVisualizer(colors: parsePalette(detail.viz_palette))
                                .frame(height: 200)
                                .background(Theme.cardBackground.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Theme.cardBorder, lineWidth: 1)
                                )
                            
                            // Visualizer label hud
                            HStack(spacing: 6) {
                                Circle().fill(Theme.neonGreen).frame(width: 6, height: 6)
                                Text("VIZ_PALETTE RENDER")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(12)
                        }
                        .padding(.horizontal)
                        
                        // Summary & preparation info
                        VStack(alignment: .leading, spacing: 12) {
                            Text("OPTIMIZATION SCHEMATICS")
                                .font(.system(.caption, design: .monospaced, weight: .bold))
                                .foregroundStyle(Theme.brandBlue)
                                .tracking(1)
                            
                            Text(detail.summary)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.white.opacity(0.7))
                            
                            Divider().background(Theme.cardBorder)
                            
                            HStack(spacing: 16) {
                                DetailSpecBox(label: "PREP TIME", value: "\(detail.duration_min) MIN")
                                DetailSpecBox(label: "CALORIES", value: "\(detail.macros.calories) KCAL")
                                DetailSpecBox(label: "PROTEIN", value: "\(detail.macros.protein_g)G")
                                DetailSpecBox(label: "CARBS", value: "\(detail.macros.carbs_g)G")
                                DetailSpecBox(label: "FATS", value: "\(detail.macros.fats_g)G")
                            }
                        }
                        .padding()
                        .background(Theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Theme.cardBorder, lineWidth: 1)
                        )
                        .padding(.horizontal)
                        
                        // Ingredients section with checkable list
                        VStack(alignment: .leading, spacing: 12) {
                            Text("REQUIRED INGREDIENTS")
                                .font(.system(.caption, design: .monospaced, weight: .bold))
                                .foregroundStyle(Theme.brandBlue)
                                .tracking(1)
                                .padding(.horizontal)
                            
                            VStack(spacing: 0) {
                                ForEach(detail.ingredients, id: \.name) { ingredient in
                                    let isChecked = checklistIngredients.contains(ingredient.name)
                                    Button {
                                        if isChecked {
                                            checklistIngredients.remove(ingredient.name)
                                        } else {
                                            checklistIngredients.insert(ingredient.name)
                                        }
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                                                .font(.headline)
                                                .foregroundStyle(isChecked ? Theme.neonGreen : .white.opacity(0.3))
                                            
                                            Text(ingredient.name.capitalized)
                                                .font(.system(.subheadline, design: .rounded))
                                                .foregroundStyle(isChecked ? .white.opacity(0.5) : .white)
                                                .strikethrough(isChecked)
                                            
                                            Spacer()
                                            
                                            Text(ingredient.qty)
                                                .font(.system(.caption, design: .monospaced))
                                                .foregroundStyle(.white.opacity(0.4))
                                        }
                                        .padding(.vertical, 12)
                                        .padding(.horizontal)
                                        .background(isChecked ? Color.white.opacity(0.01) : Color.clear)
                                    }
                                    
                                    if ingredient != detail.ingredients.last {
                                        Divider().background(Theme.cardBorder)
                                            .padding(.horizontal)
                                    }
                                }
                            }
                            .background(Theme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Theme.cardBorder, lineWidth: 1)
                            )
                            .padding(.horizontal)
                        }
                        
                        // Steps section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("COOKING PROTOCOLS")
                                .font(.system(.caption, design: .monospaced, weight: .bold))
                                .foregroundStyle(Theme.brandBlue)
                                .tracking(1)
                            
                            ForEach(0..<detail.steps.count, id: \.self) { idx in
                                HStack(alignment: .top, spacing: 14) {
                                    Text("\(idx + 1)")
                                        .font(.system(.caption, design: .monospaced, weight: .heavy))
                                        .foregroundStyle(Theme.brandCyan)
                                        .frame(width: 22, height: 22)
                                        .background(Theme.brandCyan.opacity(0.1))
                                        .clipShape(Circle())
                                    
                                    Text(detail.steps[idx])
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.85))
                                        .lineSpacing(4)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .padding()
                        .background(Theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Theme.cardBorder, lineWidth: 1)
                        )
                        .padding(.horizontal)
                        
                        // Instacart deep link block if returned
                        if let cart = instacartResult {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("INSTACART CART GENERATED")
                                    .font(.system(.caption, design: .monospaced, weight: .bold))
                                    .foregroundStyle(Theme.neonGreen)
                                
                                Text(cart.note)
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.7))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("STAGED ITEMS:")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.4))
                                    
                                    ForEach(cart.items, id: \.self) { item in
                                        Text("• \(item)")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(Theme.brandCyan)
                                    }
                                }
                                .padding(.top, 4)
                                
                                Text(cart.policy_note)
                                    .font(.system(size: 8, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.4))
                                    .padding(.top, 4)
                                
                                Button {
                                    openCartDeepLink(cart)
                                } label: {
                                    Text("LAUNCH INSTACART APP")
                                        .font(.system(.subheadline, design: .monospaced, weight: .heavy))
                                        .foregroundStyle(.black)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 48)
                                        .background(Capsule().fill(Theme.neonGreen))
                                }
                                .padding(.top, 8)
                            }
                            .padding()
                            .background(Theme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Theme.neonGreen.opacity(0.3), lineWidth: 1)
                            )
                            .padding(.horizontal)
                        }
                        
                        // Action: Instacart trigger
                        Button {
                            Task { await buildInstacartCart() }
                        } label: {
                            HStack {
                                if loadingInstacart {
                                    ProgressView()
                                        .tint(.black)
                                        .scaleEffect(0.8)
                                        .padding(.trailing, 8)
                                } else {
                                    Image(systemName: "cart.fill")
                                }
                                Text("SEND INGREDIENTS TO INSTACART")
                                    .font(.system(.subheadline, design: .monospaced, weight: .heavy))
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Capsule().fill(Theme.brandCyan))
                            .padding(.horizontal)
                            .padding(.bottom, 32)
                        }
                        .disabled(loadingInstacart)
                    }
                }
            }
        }
    }
    
    private func buildInstacartCart() async {
        loadingInstacart = true
        do {
            let res = try await BioFuelService.shared.instacartCart(recipeId: detail.id)
            self.instacartResult = res
            loadingInstacart = false
            FelToastCenter.shared.show("Staged cart for Instacart", isError: false)
            
            // Automatically launch deep link
            openCartDeepLink(res)
        } catch {
            FelToastCenter.shared.show("Instacart builder failed: \(error.localizedDescription)", isError: true)
            loadingInstacart = false
        }
    }
    
    private func openCartDeepLink(_ cart: InstacartCartResult) {
        if let url = URL(string: cart.deep_link), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let fallback = URL(string: cart.fallback_url) {
            UIApplication.shared.open(fallback)
        }
    }
}

private struct DetailSpecBox: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Helper to parse colors from viz_palette
private func parsePalette(_ hexStrings: [String]) -> [UIColor] {
    var list: [UIColor] = []
    for hex in hexStrings {
        if let uiColor = UIColor(hex: hex) {
            list.append(uiColor)
        }
    }
    if list.isEmpty {
        list = [.systemCyan, .systemBlue]
    }
    return list
}

// Extension to init UIColor from hex string
extension UIColor {
    convenience init?(hex: String) {
        var cString: String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if cString.hasPrefix("#") {
            cString.remove(at: cString.startIndex)
        }

        if cString.count != 6 {
            return nil
        }

        var rgbValue: UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)

        self.init(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
}

// MARK: - SceneKit rotating colors helper
private struct Recipe3DVisualizer: UIViewRepresentable {
    let colors: [UIColor]
    
    func makeUIView(context: Context) -> SCNView {
        let v = SCNView()
        let scene = SCNScene()
        scene.background.contents = UIColor.clear
        
        // Add a camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0, 2.8)
        scene.rootNode.addChildNode(cameraNode)
        
        // Add a lighting node
        let light = SCNLight()
        light.type = .omni
        light.color = UIColor.white
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.position = SCNVector3(0, 5, 5)
        scene.rootNode.addChildNode(lightNode)
        
        // Add ambient light
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = UIColor(white: 0.4, alpha: 1.0)
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)
        
        // Group node to rotate everything slowly
        let groupNode = SCNNode()
        
        for (index, color) in colors.enumerated() {
            let radius = 0.45 + Double(index) * 0.20
            let pipeRadius = 0.024
            let torus = SCNTorus(ringRadius: radius, pipeRadius: pipeRadius)
            
            let mat = SCNMaterial()
            mat.diffuse.contents = color
            mat.emission.contents = color.withAlphaComponent(0.65)
            mat.roughness.contents = 0.1
            mat.metalness.contents = 0.95
            torus.materials = [mat]
            
            let ringNode = SCNNode(geometry: torus)
            ringNode.eulerAngles.x = Float.pi / 4 * Float(index + 1)
            ringNode.eulerAngles.y = Float.pi / 6 * Float(index)
            
            let direction: CGFloat = (index % 2 == 0) ? 1.0 : -1.0
            let spinSpeed: Double = 4.0 + Double(index) * 2.0
            let spin = SCNAction.repeatForever(SCNAction.rotateBy(x: 0.15 * direction, y: 1.0 * direction, z: 0.25 * direction, duration: spinSpeed))
            ringNode.runAction(spin)
            
            groupNode.addChildNode(ringNode)
        }
        
        scene.rootNode.addChildNode(groupNode)
        v.scene = scene
        v.autoenablesDefaultLighting = true
        v.backgroundColor = .clear
        v.allowsCameraControl = true
        
        // Slow overall spin
        let groupSpin = SCNAction.repeatForever(SCNAction.rotateBy(x: 0.1, y: 0.2, z: 0.0, duration: 10.0))
        groupNode.runAction(groupSpin)
        
        return v
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {}
}
