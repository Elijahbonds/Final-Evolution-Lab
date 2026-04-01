import SwiftUI

struct SettingsSheet: View {
    @Binding var simpleMode: Bool
    let viewModel: LabViewModel?
    @Environment(\.dismiss) private var dismiss
    @State private var showExportAlert: Bool = false
    @State private var exportJSON: String = ""
    @AppStorage(FELArenaRuntimePreference.userDefaultsKey) private var arenaRuntimeRaw: String = FELArenaRuntimePreference.labSceneKit.rawValue
    @AppStorage(FELArenaRuntimePreference.pixelStreamingURLKey) private var pixelStreamURL: String = ""
    @AppStorage(FELArenaDiagnosticsPreference.userDefaultsKey) private var arenaDiagnosticsOverlayEnabled: Bool = false

    private var arenaRuntimeBinding: Binding<FELArenaRuntimePreference> {
        Binding(
            get: { FELArenaRuntimePreference(rawValue: arenaRuntimeRaw) ?? .labSceneKit },
            set: { arenaRuntimeRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker(selection: arenaRuntimeBinding) {
                        ForEach(FELArenaRuntimePreference.allCases) { mode in
                            Text(mode.displayTitle).tag(mode)
                        }
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Arena experience")
                                    .font(.body.weight(.semibold))
                                Text(FELArenaRuntimePreference(rawValue: arenaRuntimeRaw)?.detail ?? "")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "cube.transparent")
                                .foregroundStyle(Theme.brandCyan)
                        }
                    }
                    .tint(Theme.brandBlue)
                    TextField("Pixel Streaming URL (optional https)", text: $pixelStreamURL)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .foregroundStyle(.primary)
                } header: {
                    Text("Unreal / Arena")
                } footer: {
                    Text("Ship target is one iOS gaming app: the Unreal packaged build (Sovereign Lab). This Swift shell is legacy lab UI; full simulation is UE on device or Pixel Streaming below. See UNREAL_ONLY.md.")
                        .font(.caption2)
                }

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
                    .onChange(of: simpleMode) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "simpleMode")
                    }
                    Toggle(isOn: $arenaDiagnosticsOverlayEnabled) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Arena diagnostics")
                                    .font(.body.weight(.semibold))
                                Text("Skeleton overlay and form labels during play")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "figure.walk.motion")
                                .foregroundStyle(Theme.brandCyan)
                        }
                    }
                    .tint(Theme.brandBlue)
                } header: {
                    Text("Display")
                } footer: {
                    Text("When off, arena play hides the live skeleton and MODERATE / LEAKING form readouts. DEBUG builds default this on once; release defaults off until you enable it.")
                        .font(.caption2)
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
