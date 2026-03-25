import SwiftUI

struct SettingsSheet: View {
    @Binding var simpleMode: Bool
    let viewModel: LabViewModel?
    @Environment(\.dismiss) private var dismiss
    @AppStorage("felDemoModeShowcase") private var felDemoModeShowcase = false
    @AppStorage(GameQualityPreset.userDefaultsKey) private var gameQualityRaw = GameQualityPreset.standard.rawValue
    @State private var showExportAlert: Bool = false
    @State private var exportJSON: String = ""
    @State private var inviteCodeInput: String = ""
    @State private var inviteFeedback: String?
    @State private var sovereignEmail: String = ""
    @State private var sovereignPassword: String = ""
    @State private var sovereignBusy: Bool = false
    @State private var sovereignMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if let vm = viewModel {
                    Section {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Sovereign wallet")
                                    .font(.title3.weight(.bold))
                                Text("Shards, Cloud Cortex, Vertical Velocity Blueprint")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(Theme.brandCyan)
                        }
                        .listRowSeparator(.hidden, edges: .bottom)

                        TextField("Supabase email", text: $sovereignEmail)
                            .textContentType(.username)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField("Password", text: $sovereignPassword)
                            .textContentType(.password)
                        Button(sovereignBusy ? "Signing in…" : "Sign in — link checkout & live wallet") {
                            sovereignBusy = true
                            sovereignMessage = nil
                            Task {
                                let ok = await FELSupabaseWalletSync.shared.signIn(
                                    email: sovereignEmail.trimmingCharacters(in: .whitespacesAndNewlines),
                                    password: sovereignPassword,
                                    labViewModel: vm
                                )
                                await MainActor.run {
                                    sovereignBusy = false
                                    if ok {
                                        sovereignPassword = ""
                                        sovereignMessage = "Wallet live — shards update after purchase."
                                    } else {
                                        sovereignMessage = FELSupabaseWalletSync.shared.lastErrorMessage
                                    }
                                }
                            }
                        }
                        .disabled(sovereignBusy || sovereignEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sovereignPassword.isEmpty)
                        if let msg = sovereignMessage, !msg.isEmpty {
                            Text(msg)
                                .font(.caption)
                                .foregroundStyle(msg.contains("live") ? Theme.brandCyan : .orange)
                        }
                        if let sid = vm.profile.supabaseUserId {
                            Text("Linked: \(sid.prefix(8))…")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Button("Sign out", role: .destructive) {
                            Task {
                                await FELSupabaseWalletSync.shared.signOut()
                                await MainActor.run {
                                    var p = vm.profile
                                    p.supabaseUserId = nil
                                    vm.profile = p
                                    SaveSystem.saveProfile(p)
                                    sovereignMessage = "Signed out."
                                }
                            }
                        }
                    } header: {
                        Text("Economy & Academy unlocks")
                    } footer: {
                        Text("Use the same account as FinalEvolutionGroup.com checkout. Stripe credits user_balances; the app links your local athlete id for forensic tracking.")
                    }
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
                    Toggle(isOn: $felDemoModeShowcase) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Demo Mode")
                                    .font(.body.weight(.semibold))
                                Text("System Scan shows Fast-Track using cached AvatarRig data")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "sparkles.tv")
                                .foregroundStyle(Theme.brandCyan)
                        }
                    }
                    .tint(Theme.brandCyan)
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

                Section {
                    NavigationLink {
                        CoachMarketImpactView()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Coach Dashboard")
                                    .font(.body.weight(.semibold))
                                Text("Stands, skins sold, 70/30 revenue ledger")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundStyle(Theme.brandCyan)
                        }
                    }
                    if let vm = viewModel {
                        NavigationLink {
                            ScoutsPortalView(viewModel: vm)
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Scout's Portal")
                                        .font(.body.weight(.semibold))
                                    Text("CSV season report for recruiters & coaches")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "binoculars.fill")
                                    .foregroundStyle(Theme.brandBlue)
                            }
                        }
                    }
                } header: {
                    Text("Creator Economy")
                }

                Section {
                    TextField("FELSV1.…", text: $inviteCodeInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Save Pro-Coach invite") {
                        let ok = UFELCreatorInviteService.shared.registerPendingInviteCode(inviteCodeInput)
                        inviteFeedback = ok
                            ? "Linked on your first System Scan."
                            : "Invalid code. Ask your coach for a Sovereign Invite."
                    }
                    .disabled(inviteCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if let f = inviteFeedback {
                        Text(f)
                            .font(.caption)
                            .foregroundStyle(f.contains("Invalid") ? .orange : Theme.brandCyan)
                    }
                    if let vm = viewModel, let cid = vm.profile.linkedCoachCreatorId {
                        Label("Coach CreatorID: \(cid)", systemImage: "link.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Pro-Coach")
                } footer: {
                    Text("Enter your coach’s Sovereign Invite before the first System Scan to join their roster. Ghost Sync uses local network with peer discovery.")
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
            .onAppear {
                if inviteCodeInput.isEmpty, let pending = UFELCreatorInviteService.shared.pendingInviteCodeDisplay {
                    inviteCodeInput = pending
                }
            }
        }
        .presentationDetents([.medium, .large])
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
