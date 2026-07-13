import SwiftUI

struct SettingsSheet: View {
    @Binding var simpleMode: Bool
    let viewModel: LabViewModel?
    @Environment(\.dismiss) private var dismiss
    @State private var showExportAlert: Bool = false
    @State private var exportJSON: String = ""
    @State private var showControllerTest: Bool = false
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
                        SettingsRowLabel(
                            title: "Firebase emulators",
                            subtitle: "Auth \(Config.authEmulatorHost):\(Config.authEmulatorPort) · Firestore \(Config.firestoreEmulatorHost) · Data Connect \(Config.dataConnectEmulatorHost):\(Config.dataConnectEmulatorPort). Restart after changing.",
                            icon: "laptopcomputer.and.iphone"
                        )
                    }
                    .tint(FELDesign.Colors.cyan)
                } header: {
                    FELMicroLabel(text: "Integration (local)")
                }
                .listRowBackground(FELDesign.Colors.surface)
#endif

                Section {
                    Toggle(isOn: $useEmulatorShell) {
                        SettingsRowLabel(
                            title: "Emulator shell",
                            subtitle: "Cartridge library, boot splash, and in-game quick-switch",
                            icon: "gamecontroller.fill"
                        )
                    }
                    .tint(FELDesign.Colors.cyan)

                    Toggle(isOn: $crtScanlinesEnabled) {
                        SettingsRowLabel(
                            title: "CRT scanlines",
                            subtitle: "Subtle retro overlay on library and gameplay",
                            icon: "tv"
                        )
                    }
                    .tint(FELDesign.Colors.cyan)
                    .disabled(!useEmulatorShell)

                    Toggle(isOn: $simpleMode) {
                        SettingsRowLabel(
                            title: "Simple Mode",
                            subtitle: "Family-friendly labels for all metrics",
                            icon: "figure.and.child.holdinghands"
                        )
                    }
                    .tint(FELDesign.Colors.cyan)
                    .onChange(of: simpleMode) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "simpleMode")
                    }
                } header: {
                    FELMicroLabel(text: "Display")
                }
                .listRowBackground(FELDesign.Colors.surface)

                if let vm = viewModel, let age = vm.profile.age, age < 18 {
                    Section {
                        Toggle(isOn: Binding(
                            get: { vm.profile.guardianConsentForMinorFeatures },
                            set: { newValue in
                                vm.profile.guardianConsentForMinorFeatures = newValue
                                SaveSystem.saveProfile(vm.profile)
                            }
                        )) {
                            SettingsRowLabel(
                                title: "Guardian consent",
                                subtitle: "Required for community posts, HealthKit, and paid coach critiques.",
                                icon: "figure.and.child.holdinghands"
                            )
                        }
                        .tint(FELDesign.Colors.cyan)
                    } header: {
                        FELMicroLabel(text: "Safety (under 18)")
                    }
                    .listRowBackground(FELDesign.Colors.surface)
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
                            SettingsRowLabel(
                                title: "Export Unity Manifest",
                                subtitle: "JSON export of PRQ, Neural Drive & game data",
                                icon: "square.and.arrow.up"
                            )
                        }
                    } header: {
                        FELMicroLabel(text: "Unity Bridge")
                    }
                    .listRowBackground(FELDesign.Colors.surface)
                }

                Section {
                    Button {
                        showControllerTest = true
                    } label: {
                        SettingsRowLabel(
                            title: "Controller Test Scene",
                            subtitle: "Shared gamepad + design tokens, landscape",
                            icon: "gamecontroller"
                        )
                    }
                } header: {
                    FELMicroLabel(text: "Developer")
                }
                .listRowBackground(FELDesign.Colors.surface)

                Section {
                    Label {
                        Text("Version 2.0")
                            .font(FELDesign.Typography.body)
                    } icon: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(FELDesign.Colors.textTertiary)
                    }
                    .foregroundStyle(FELDesign.Colors.textSecondary)
                } header: {
                    FELMicroLabel(text: "About")
                }
                .listRowBackground(FELDesign.Colors.surface)
            }
            .scrollContentBackground(.hidden)
            .background(FELDesign.Colors.ink)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(FELDesign.Colors.cyan)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(FELDesign.Colors.ink)
        .fullScreenCover(isPresented: $showControllerTest) {
            ControllerTestSceneView()
        }
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

/// Icon + title/subtitle row used across all Settings sections.
private struct SettingsRowLabel: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FELDesign.Typography.label)
                    .foregroundStyle(FELDesign.Colors.textPrimary)
                Text(subtitle)
                    .font(FELDesign.Typography.caption)
                    .foregroundStyle(FELDesign.Colors.textSecondary)
            }
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(FELDesign.Colors.cyan)
        }
    }
}
