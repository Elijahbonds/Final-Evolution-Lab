import SwiftUI

struct SettingsSheet: View {
    @Binding var simpleMode: Bool
    let viewModel: LabViewModel?
    @Environment(\.dismiss) private var dismiss
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
                                    .foregroundStyle(AnyShapeStyle(.secondary))
                            }
                        } icon: {
                            Image(systemName: "figure.and.child.holdinghands")
                                .foregroundStyle(Theme.brandBlue)
                        }
                    }
                    .tint(Theme.brandBlue)
                    .onChange(of: simpleMode) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "simpleMode")
                    }
                } header: {
                    Text("Display")
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
                            if let json {
                                exportJSON = json
                                UnityManager.shared.sendManifestToUnity(json)
                            } else {
                                exportJSON = "Export failed"
                            }
                            showExportAlert = true
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Export Unity Manifest")
                                        .font(.body.weight(.semibold))
                                    Text("JSON export of PRQ, Neural Drive & game data")
                                        .font(.caption)
                                        .foregroundStyle(AnyShapeStyle(.secondary))
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
                            .foregroundStyle(AnyShapeStyle(.secondary))
                    }
                    .foregroundStyle(AnyShapeStyle(.secondary))
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
