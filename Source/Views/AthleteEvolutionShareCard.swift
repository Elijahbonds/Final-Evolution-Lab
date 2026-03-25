import SwiftUI
import UIKit

/// Social “Athlete Card” preview — same layout as `UFELAthleteCardGenerator` export.
struct AthleteEvolutionShareCard: View {
    let viewModel: LabViewModel

    private var input: UFELAthleteCardGenerator.CardInput {
        UFELAthleteCardGenerator.cardInput(from: viewModel)
    }

    var body: some View {
        FELAthleteCardCanvas(input: input)
            .frame(width: 390, height: 520)
    }
}

enum AthleteEvolutionShareRenderer {
    @MainActor
    static func renderImage(viewModel: LabViewModel) -> UIImage? {
        UFELAthleteCardGenerator.renderFromLabViewModel(viewModel)
    }
}
