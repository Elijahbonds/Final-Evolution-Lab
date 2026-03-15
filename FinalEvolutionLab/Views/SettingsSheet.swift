import SwiftUI

struct SettingsSheet: View {
    @Binding var simpleMode: Bool
    let viewModel: LabViewModel?
    @Environment(\.dismiss) private var dismiss
    @AppStorage(GameQualityPreset.userDefaultsKey) private var gameQualityRaw = GameQualityPreset.standard.rawValue
    @State private var showExportAlert: Bool = false
    @State private var exportJSON: String = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $simpleMode) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Simple Mode")
                                    .font(.body.weight(.semibold))
                                Text("Family-friendly labels for all metrics")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "figure.and.child.holdinghands")
                                .foregroundStyle(Theme.brandBlue)
                        }
                    }
                    .tint(Theme.brandBlue)
                } header: {
                    Text("Display")
                }

                Section {
                    Picker(selection: $gameQualityRaw) {
                        ForEach(GameQualityPreset.allCases) { preset in
                            Text(preset.displayName).tag(preset.rawValue)
                        }
                    } label: {
                        Label {
                            Text("Quality")
                                .font(.body.weight(.semibold))
                        } icon: {
                            Image(systemName: "gauge.with.dots.needle.67percent")
                                .foregroundStyle(Theme.brandCyan)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.brandCyan)
                } header: {
                    Text("Graphics")
                } footer: {
                    Text("High: 60fps, best visuals. Standard: 60fps, balanced. Performance: 30fps for battery and older devices. Applies on next game load.")
                }

                if let vm = viewModel {
                    Section {
                        Button {
                            let json = UnityExportBuilder.exportJSON(
                                profile: vm.profile,
                                metrics: vm.effectiveMetrics,
                                arcade: vm.arcadePhysics,
                                audit: vm.biomechanicsAudit
                            )
                            exportJSON = json ?? "Export failed"
                            showExportAlert = true
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Export Unity Manifest")
                                        .font(.body.weight(.semibold))
                                    Text("JSON export of PRQ, Neural Drive & game data")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundStyle(Theme.brandCyan)
                            }
                        }
                    } header: {
                        Text("Unity Bridge")
                    }
                }

                Section {
                    Label {
                        Text("Version 2.0")
                    } icon: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.secondary)
                } header: {
                    Text("About")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.deepBlack)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.brandBlue)
                        .accessibilityHint("Closes settings")
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(Theme.deepBlack)
        .alert("Unity Manifest", isPresented: $showExportAlert) {
            Button("Copy to Clipboard") {
                UIPasteboard.general.string = exportJSON
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text("JSON manifest generated (\(exportJSON.count) chars). Copy to clipboard for Unity import.")
        }
    }
}
