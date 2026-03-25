import SwiftUI

/// Unreal is not embedded like UnityFramework. Shipping UE on iOS uses Epic’s packaged app / plugin workflow.
/// This view documents the “emulator shell” intent: same product surface; engine build is a separate UE target.
struct UnrealRuntimePlaceholderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("UNREAL RUNTIME")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(Theme.brandCyan)
            Text("Arena gameplay is authored in Unreal Engine. This iOS shell hosts Film Vault, Stream, and Lab flows; embed or deep-link the UE iOS build per Epic packaging.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text("Unity uses `UnityFramework` when embedded. Unreal: package iOS from your `.uproject` and integrate via URL scheme, Pixel Streaming, or native UE plugin—see UNREAL_ONLY.md in the repo.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary.opacity(0.9))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Theme.brandCyan.opacity(0.25), lineWidth: 1)
                )
        )
    }
}
