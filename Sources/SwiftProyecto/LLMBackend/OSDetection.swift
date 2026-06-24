//
//  OSDetection.swift
//  SwiftProyecto
//
//  Copyright (c) 2025 Intrusive Memory
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

import Foundation

/// Detect the current operating system version.
///
/// This function returns the major and minor version numbers of the current OS.
/// On macOS, it parses the system version from ProcessInfo.
///
/// ## Platform-Specific Backends
///
/// Backends can use this function to determine platform support:
///
/// ```swift
/// let (major, minor) = macOSVersion()
/// if major >= 27 {
///   // Use Foundation Models (macOS 27+ only)
/// }
/// ```
///
/// - Returns: Tuple of (major: Int, minor: Int) version components
public func macOSVersion() -> (major: Int, minor: Int) {
  let version = ProcessInfo.processInfo.operatingSystemVersion
  return (major: version.majorVersion, minor: version.minorVersion)
}

/// Check if the current macOS version meets a minimum requirement.
///
/// - Parameters:
///   - major: Required major version
///   - minor: Required minor version (default 0)
/// - Returns: `true` if current macOS >= required version
public func isMacOSVersionAtLeast(major: Int, minor: Int = 0) -> Bool {
  let (currentMajor, currentMinor) = macOSVersion()

  if currentMajor > major {
    return true
  }

  if currentMajor == major {
    return currentMinor >= minor
  }

  return false
}
