// Linux shim: QuartzCore is Apple-only. Type-check only, never shipped.
import Foundation
public func CACurrentMediaTime() -> Double { Date().timeIntervalSinceReferenceDate }
