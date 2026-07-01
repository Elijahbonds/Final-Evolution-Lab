import SwiftUI

// MARK: - NexusEditorView

/// In-app scene editor for the Nexus game engine.
///
/// Layout: entity list (left) | scene viewport (center) | component inspector (right).
/// Scenes can be exported as JSON and loaded at runtime via NexusRenderer.
struct NexusEditorView: View {
    @Binding var scene: NexusScene
    var onSave: ((NexusScene) -> Void)?

    @State private var selectedEntityId: String?
    @State private var showAddEntitySheet: Bool = false
    @State private var showExportSheet: Bool = false
    @State private var exportJSON: String = ""
    @State private var isPlaying: Bool = false
    @State private var showDebug: Bool = false
    @State private var zoom: CGFloat = 1.0

    private var selectedEntity: Binding<NexusEntity>? {
        guard let id = selectedEntityId,
              let index = scene.entities.firstIndex(where: { $0.id == id }) else { return nil }
        return $scene.entities[index]
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                entitySidebar
                    .frame(width: 200)

                Divider()
                    .background(Color.white.opacity(0.06))

                sceneViewport
                    .frame(maxWidth: .infinity)

                Divider()
                    .background(Color.white.opacity(0.06))

                inspectorPanel
                    .frame(width: 220)
            }
            .background(Theme.deepBlack)
            .navigationTitle("Nexus Editor — \(scene.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { editorToolbar }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showAddEntitySheet) {
                AddEntitySheet(scene: $scene)
            }
            .sheet(isPresented: $showExportSheet) {
                SceneExportSheet(json: exportJSON)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Entity Sidebar

    private var entitySidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            sidebarHeader("ENTITIES", count: scene.entities.count)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(scene.entities) { entity in
                        EntityRow(
                            entity: entity,
                            isSelected: selectedEntityId == entity.id
                        )
                        .onTapGesture { selectedEntityId = entity.id }
                        .contextMenu {
                            Button(role: .destructive) {
                                scene.entities.removeAll { $0.id == entity.id }
                                if selectedEntityId == entity.id { selectedEntityId = nil }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                var copy = entity
                                copy = NexusEntity(
                                    id: UUID().uuidString,
                                    name: entity.name + " Copy",
                                    transform: entity.transform,
                                    components: entity.components
                                )
                                scene.entities.append(copy)
                            } label: {
                                Label("Duplicate", systemImage: "plus.square.on.square")
                            }
                        }
                    }
                }
                .padding(8)
            }

            Button {
                showAddEntitySheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                    Text("ADD ENTITY")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(Theme.brandBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Theme.brandBlue.opacity(0.08))
            }
        }
        .background(Theme.cardBackground)
    }

    // MARK: - Scene Viewport

    private var sceneViewport: some View {
        VStack(spacing: 0) {
            // Toolbar row
            HStack(spacing: 12) {
                Button {
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(isPlaying ? .red : Theme.neonGreen)
                }

                Toggle("Debug", isOn: $showDebug)
                    .toggleStyle(.button)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tint(Theme.brandBlue)

                Spacer()

                HStack(spacing: 4) {
                    Button {
                        zoom = max(0.5, zoom - 0.1)
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    Text("\(Int(zoom * 100))%")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 36)
                    Button {
                        zoom = min(2.0, zoom + 0.1)
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                    }
                }
                .foregroundStyle(.secondary)
                .font(.system(size: 12))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.surfaceElevated)

            // Viewport
            ZStack {
                if isPlaying {
                    NexusSceneView(
                        scene: scene,
                        physics: NexusRenderer.shared.playerPhysics,
                        showDebugOverlay: showDebug
                    )
                    .scaleEffect(zoom)
                } else {
                    NexusSceneView(
                        scene: scene,
                        physics: NexusRenderer.shared.playerPhysics,
                        showDebugOverlay: true
                    )
                    .scaleEffect(zoom)
                    .overlay(pausedOverlay)
                }

                // Entity selection highlights
                if !isPlaying, let id = selectedEntityId,
                   let entity = scene.entities.first(where: { $0.id == id }) {
                    GeometryReader { geo in
                        let pos = entity.transform.resolvedPosition(in: geo.size)
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Theme.brandBlue, lineWidth: 1.5)
                            .frame(width: 44, height: 44)
                            .position(pos)
                    }
                }
            }
            .clipped()
        }
    }

    private var pausedOverlay: some View {
        VStack {
            HStack {
                Spacer()
                Text("PAUSED — EDITOR MODE")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.orange.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.08))
                    .clipShape(Capsule())
                Spacer()
            }
            .padding(.top, 12)
            Spacer()
        }
    }

    // MARK: - Inspector Panel

    private var inspectorPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            sidebarHeader("INSPECTOR", count: nil)

            ScrollView {
                if let binding = selectedEntity {
                    EntityInspector(entity: binding, scene: $scene)
                } else {
                    SceneInspector(scene: $scene)
                }
            }
        }
        .background(Theme.cardBackground)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var editorToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                exportJSON = exportSceneJSON()
                showExportSheet = true
            } label: {
                Label("Export", systemImage: "arrow.up.doc")
            }

            Button {
                onSave?(scene)
            } label: {
                Label("Save", systemImage: "checkmark")
            }
            .tint(Theme.neonGreen)
        }
    }

    // MARK: - Helpers

    private func sidebarHeader(_ title: String, count: Int?) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(2)
            if let count {
                Text("\(count)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.brandBlue)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.surfaceElevated)
    }

    private func exportSceneJSON() -> String {
        guard let data = try? JSONEncoder().encode(scene),
              let pretty = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: pretty, options: .prettyPrinted),
              let string = String(data: prettyData, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}

// MARK: - EntityRow

private struct EntityRow: View {
    let entity: NexusEntity
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: entityIcon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isSelected ? Theme.brandBlue : .secondary)
                .frame(width: 20)

            Text(entity.name)
                .font(.system(size: 12, weight: isSelected ? .bold : .regular, design: .monospaced))
                .foregroundStyle(isSelected ? .white : .secondary)
                .lineLimit(1)

            Spacer()

            if !entity.isEnabled {
                Image(systemName: "eye.slash")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Theme.brandBlue.opacity(0.12) : .clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Theme.brandBlue.opacity(0.3) : .clear, lineWidth: 1)
                )
        )
    }

    private var entityIcon: String {
        for component in entity.components {
            if case .skeleton = component { return "figure.mixed.cardio" }
            if case .camera = component { return "camera.fill" }
            if case .trigger = component { return "circle.dashed" }
            if case .light = component { return "light.max" }
            if case .surface = component { return "rectangle.fill" }
        }
        return "cube.fill"
    }
}

// MARK: - EntityInspector

private struct EntityInspector: View {
    @Binding var entity: NexusEntity
    @Binding var scene: NexusScene

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Name
            inspectorSection("ENTITY") {
                TextField("Name", text: $entity.name)
                    .font(.system(size: 12, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 12)

                Toggle("Enabled", isOn: $entity.isEnabled)
                    .font(.system(size: 12))
                    .padding(.horizontal, 12)
            }

            // Transform
            inspectorSection("TRANSFORM") {
                VStack(spacing: 6) {
                    transformRow("X", value: $entity.transform.position.x)
                    transformRow("Y", value: $entity.transform.position.y)
                    transformRow("Rotation", value: $entity.transform.rotation)
                    transformRow("Scale", value: $entity.transform.scale)
                }
                .padding(.horizontal, 12)
            }

            // Components
            inspectorSection("COMPONENTS") {
                ForEach(entity.components.indices, id: \.self) { i in
                    componentRow(entity.components[i])
                        .padding(.horizontal, 12)
                }
            }
        }
    }

    private func inspectorSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(2)
                .padding(.horizontal, 12)
                .padding(.top, 12)

            content()

            Divider()
                .background(Color.white.opacity(0.06))
                .padding(.top, 8)
        }
    }

    private func transformRow(_ label: String, value: Binding<CGFloat>) -> some View {
        let doubleBinding = Binding<Double>(
            get: { Double(value.wrappedValue) },
            set: { value.wrappedValue = CGFloat($0) }
        )
        return HStack {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)
            Slider(value: doubleBinding, in: 0...1)
                .tint(Theme.brandBlue)
            Text(String(format: "%.2f", value.wrappedValue))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 36, alignment: .trailing)
        }
    }

    private func componentRow(_ component: NexusComponentType) -> some View {
        HStack(spacing: 8) {
            Image(systemName: component.systemImage)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.brandBlue)
                .frame(width: 16)
            Text(component.displayName)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - SceneInspector

private struct SceneInspector: View {
    @Binding var scene: NexusScene

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SCENE")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(2)
                .padding(.horizontal, 12)
                .padding(.top, 12)

            VStack(spacing: 8) {
                TextField("Scene Name", text: $scene.name)
                    .font(.system(size: 12, design: .monospaced))
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Text("Gravity")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Slider(value: $scene.physicsConfig.gravity, in: 1...20)
                        .tint(Theme.brandBlue)
                    Text(String(format: "%.1f", scene.physicsConfig.gravity))
                        .font(.system(size: 10, design: .monospaced))
                        .frame(width: 32)
                }

                HStack {
                    Text("Friction")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Slider(value: $scene.physicsConfig.frictionCoefficient, in: 0...1)
                        .tint(Theme.brandBlue)
                    Text(String(format: "%.2f", scene.physicsConfig.frictionCoefficient))
                        .font(.system(size: 10, design: .monospaced))
                        .frame(width: 32)
                }

                infoRow("Mode", scene.gameModeId.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                infoRow("Entities", "\(scene.entities.count)")
                infoRow("Speed ×", String(format: "%.2f", scene.physicsConfig.prqSpeedMultiplier))
                infoRow("Jump ×", String(format: "%.2f", scene.physicsConfig.prqJumpBonus))
            }
            .padding(.horizontal, 12)

            Text("Select an entity to inspect its components.")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .padding(12)
                .padding(.top, 8)
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - AddEntitySheet

private struct AddEntitySheet: View {
    @Binding var scene: NexusScene
    @Environment(\.dismiss) private var dismiss
    @State private var entityName: String = "New Entity"
    @State private var selectedComponent: ComponentTemplate = .skeleton

    enum ComponentTemplate: String, CaseIterable {
        case skeleton  = "Skeleton Animator"
        case physics   = "Physics Body"
        case sprite    = "Sprite"
        case trigger   = "Trigger Zone"
        case light     = "Light"

        var component: NexusComponentType {
            switch self {
            case .skeleton: .skeleton(category: .plyometric, amplitude: 1.0)
            case .physics:  .physics(mass: 70, restitution: 0.3)
            case .sprite:   .sprite(systemImage: "star.fill", hexColor: "#FFD60A")
            case .trigger:  .trigger(radius: 0.05, eventName: "trigger_\(UUID().uuidString.prefix(4))")
            case .light:    .light(intensity: 1.0, hexColor: "#FFFFFF")
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("ENTITY NAME") {
                    TextField("Name", text: $entityName)
                }
                Section("COMPONENT") {
                    Picker("Component", selection: $selectedComponent) {
                        ForEach(ComponentTemplate.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.inline)
                }
            }
            .navigationTitle("Add Entity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let entity = NexusEntity(
                            id: UUID().uuidString,
                            name: entityName,
                            transform: NexusTransform(position: CGPoint(x: 0.5, y: 0.5), rotation: 0, scale: 1),
                            components: [selectedComponent.component]
                        )
                        scene.entities.append(entity)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - SceneExportSheet

private struct SceneExportSheet: View {
    let json: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(json)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.deepBlack)
            .navigationTitle("Scene JSON")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        UIPasteboard.general.string = json
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
}

