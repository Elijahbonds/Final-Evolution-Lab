// Linux shim: OSLog is Apple-only. Surface-compatible no-ops so the portable
// core can be type-checked off-Apple. NEVER shipped — type-check only.
import Foundation
public struct Logger: Sendable {
    public init() {}
    public init(subsystem: String, category: String) {}
    public func debug(_ m: @autoclosure () -> String = "") {}
    public func info(_ m: @autoclosure () -> String = "") {}
    public func notice(_ m: @autoclosure () -> String = "") {}
    public func warning(_ m: @autoclosure () -> String = "") {}
    public func error(_ m: @autoclosure () -> String = "") {}
    public func critical(_ m: @autoclosure () -> String = "") {}
    public func fault(_ m: @autoclosure () -> String = "") {}
}
public struct OSLog: Sendable { public static let `default` = OSLog() }
