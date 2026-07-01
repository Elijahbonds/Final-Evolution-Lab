import SwiftUI

struct SettingsSheet: View {
    @Binding var simpleMode: Bool
    let viewModel: LabViewModel?
    @Environment(\.dismiss) private var dismiss
    @State private var showExportAlert: Bool = false
    @State private var exportJSON: String = ""
    @AppStorage(Config.useFirebaseEmulatorsDefaultsKey) private var useFirebaseEmulators: Bool = false
    @AppStorage(Config.emulatorShellDefaultsKey) private var useEmulatorShell: Bool = true
    @AppStorage(Config.crtScanlineDefaultsKey) private var crtScanlinesEnabled: Bool = true

    private var emulatorToggleBinding: Binding<Bool> {
        Binding(
            get: { useFirebaseEmulators },
            set: { useFirebaseEmulators = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            List {
#if DEBUG
                Section {
                    Toggle(isOn: emulatorToggleBinding) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Firebase emulators")
                                    .font(.body.weight(.semibold))
                                Text("Auth \(Config.authEmulatorHost):\(Config.authEmulatorPort) · Firestore \(Config.firestoreEmulatorHost) · Data Connect \(Config.dataConnectEmulatorHost):\(Config.dataConnectEmulatorPort). Restart after changing.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "laptopcomputer.and.iphone")
                                .foregroundStyle(Theme.brandCyan)
                        }
                    }
                    .tint(Theme.brandBlue)
                } header: {
                    Text("Integration (local)")
                }
#endif

                Section {
                    Toggle(isOn: $useEmulatorShell) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Emulator shell")
                                    .font(.body.weight(.semibold))
                                Text("Cartridge library, boot splash, and in-game quick-switch")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "gamecontroller.fill")
                                .foregroundStyle(Theme.brandCyan)
                        }
                    }
                    .tint(Theme.brandCyan)

                    Toggle(isOn: $crtScanlinesEnabled) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("CRT scanlines")
                                    .font(.body.weight(.semibold))
                                Text("Subtle retro overlay on library and gameplay")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "tv")
                                .foregroundStyle(Theme.brandBlue)
                        }
                    }
                    .tint(Theme.brandBlue)
                    .disabled(!useEmulatorShell)

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
                } header: {
                    Text("Display")
                }

                if let vm = viewModel, let age = vm.profile.age, age < 18 {
                    Section {
                        Toggle(isOn: Binding(
                            get: { vm.profile.guardianConsentForMinorFeatures },
                            set: { newValue in
                                vm.profile.guardianConsentForMinorFeatures = newValue
                                SaveSystem.saveProfile(vm.profile)
                            }
                        )) {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Guardian consent")
                                        .font(.body.weight(.semibold))
                                    Text("Required for community posts, HealthKit, and paid coach critiques.")
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
                        Text("Safety (under 18)")
                    }
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
