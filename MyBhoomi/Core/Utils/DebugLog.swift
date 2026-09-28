//
//  DebugLog.swift
//  MyBhoomi
//
//  Production-safe logging shim.
//
//  `debugLog(...)` behaves exactly like `print(...)` in DEBUG builds, and is a
//  no-op that the optimizer strips entirely from Release builds. This keeps
//  developer console output (including anything that could contain user names,
//  plot numbers, tokens, or other PII) OUT of the shipping App Store build,
//  while preserving all diagnostics during development.
//
//  Usage: replace bare `print(...)` in app source with `debugLog(...)`.
//

import Foundation

#if DEBUG
@inline(__always)
public func debugLog(_ items: Any...,
                     separator: String = " ",
                     terminator: String = "\n") {
    let line = items.map { "\($0)" }.joined(separator: separator)
    Swift.print(line, terminator: terminator)
}
#else
@inline(__always)
public func debugLog(_ items: Any...,
                     separator: String = " ",
                     terminator: String = "\n") {
    // Intentionally empty: compiled out / stripped in Release builds.
}
#endif
