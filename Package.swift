// swift-tools-version: 6.0
// Final Evolution Lab — SwiftPM manifest for tooling and CI validation.
// **Canonical app build:** open `ios/FinalEvolutionLab.xcodeproj` (no third-party SPM packages required for Gold Master).
import PackageDescription

let package = Package(
    name: "FinalEvolutionLab",
    platforms: [.iOS(.v18)],
    products: [],
    targets: [
        .target(name: "FinalEvolutionLabSPMStub", path: "tools/spm_stub")
    ]
)
