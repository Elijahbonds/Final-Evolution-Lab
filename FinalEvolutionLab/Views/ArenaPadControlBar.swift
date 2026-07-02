import SwiftUI

// MARK: - Universal pad control bar
//
// One control mechanic for every sport (GameModeId.usesArenaPad): the
// joystick + d-pad + face-button ArenaPad, translated into semantic actions
// each mode maps onto its existing verbs. Views adopt this instead of their
// bespoke bottom bars; quiz/party/rhythm/camera modes keep native touch.

/// Semantic pad events a sport view consumes.
enum ArenaPadAction: Equatable {
    case primary            // ✕ — shoot / swing / kick / serve
    case secondary          // ◯ — alt action (pump fake, slide, bunt)
    case style              // ▢ — style/trick modifier
    case special            // △ — special / power
    case direction(ArenaPadDPadDirection)
    case leftStick(CGPoint)   // aim / move (normalized -1…1)
    case rightStick(CGPoint)  // fine aim / spin
    case shoulderLeft
    case shoulderRight
}

/// Drop-in bottom control bar: ArenaPad visuals + semantic action stream.
struct ArenaPadControlBar: View {
    let accentColor: Color
    var isActive: Bool = true
    let onAction: (ArenaPadAction) -> Void

    var body: some View {
        ArenaPadOverlay(
            onFaceButton: { button in
                switch button {
                case .cross: onAction(.primary)
                case .circle: onAction(.secondary)
                case .square: onAction(.style)
                case .triangle: onAction(.special)
                }
            },
            onDPad: { onAction(.direction($0)) },
            onLeftStick: { onAction(.leftStick($0)) },
            onRightStick: { onAction(.rightStick($0)) },
            onLeftShoulder: { onAction(.shoulderLeft) },
            onRightShoulder: { onAction(.shoulderRight) },
            accentColor: accentColor,
            isActive: isActive
        )
        .frame(height: 190)
        .padding(.horizontal, 4)
    }
}
