import SwiftUI

struct SettingsSheet: View {
    @Binding var simpleMode: Bool
    @Environment(\.dismiss) private var dismiss

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
                    .onChange(of: simpleMode) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "simpleMode")
                    }
                } header: {
                    Text("Display")
                }

                Section {
                    Label {
                        Text("Version 1.0")
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
    }
}
