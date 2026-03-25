import SwiftUI
import UIKit

/// UIKit entry for the System Scan flow — hosts `SystemScanView` and supports Unreal “first contact” handoff (`readiness_snapshot.json` is written by `PRQManager` when `LabViewModel.applyScanResult` runs).
final class SystemScanViewController: UIViewController {
    var sport: String?
    var goal: String?
    var profileForDemoFastTrack: UserProfile?
    var onScanComplete: ((SystemScanResult) -> Void)?
    var onOpenAcademyModule: ((String) -> Void)?

    private var hosting: UIHostingController<SystemScanView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let scan = SystemScanView(sport: sport, goal: goal, profileForDemoFastTrack: profileForDemoFastTrack) { [weak self] result in
            self?.onScanComplete?(result)
        } onOpenAcademyModule: { [weak self] moduleId in
            self?.onOpenAcademyModule?(moduleId)
        }
        let host = UIHostingController(rootView: scan)
        hosting = host
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        host.didMove(toParent: self)
    }

    /// Digital twin calibration — same path as `SystemScanView.generateScanResult` avatar block.
    static func makeAvatarConfig(from result: SystemScanResult, sport: String?) -> AvatarSkinConfig {
        AvatarSkinConfig.fromScan(
            prq: result.prqScore,
            vertical: result.verticalEstimateInches,
            flight: result.flightTimeSeconds,
            sport: sport
        )
    }
}
