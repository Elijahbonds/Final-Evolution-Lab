// Copyright (c) Final Evolution Lab.
// AUDIT_QUALITY — forwards `FELLuminanceAnalyzer` ambient shifts to embedded UE (`FEL_IOS_OnAmbientLuminanceChanged` in `FELNativeBridge_IOS.mm`).

import Darwin
import Foundation

enum FELUnrealLuminanceBridge {
    /// When the merged Unreal iOS host is linked, adjusts follow-camera post process for Sonic Flare visibility.
    static func notifyEmbeddedUnrealAmbientChanged(luma: Float, previous: Float?) {
        guard let p = previous else { return }
        let delta = abs(p - luma)
        guard delta > 0.04 else { return }
        guard let handle = dlopen(nil, RTLD_NOW) else { return }
        guard let sym = dlsym(handle, "FEL_IOS_OnAmbientLuminanceChanged") else { return }
        typealias LumaFn = @convention(c) (Float, Float) -> Void
        let fn = unsafeBitCast(sym, to: LumaFn.self)
        fn(luma, delta)
    }
}
