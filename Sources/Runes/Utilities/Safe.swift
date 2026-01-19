//
//  Safe.swift
//  Runes
//
//  Created by Michael Long on 1/18/26.
//

import Foundation

/// The global `safe` function returns a safe, unwrapped version of the passed reference. If the reference is nil,
/// the function throws an `InstanceError`.
///
/// This is useful in situations like the following where we need to capture and use `weak self`.
/// ```swift
/// class TestService {
///    lazy var integers: SharedAsyncStream<Int> = .init { [weak self] in
///         try await safe(self).initialLoad()
///    }
///
///    private func initialLoad() async throws -> Int {
///        ...
///    }
/// ```
/// From a practical standpoint it's really just s way to avoid boilerplate.
/// ```swift
/// class TestService {
///    lazy var integers: SharedAsyncStream<Int> = .init { [weak self] in
///         guard let self else { throw InstanceError.none }
///         try await self.initialLoad()
///    }
///
///    private func initialLoad() async throws -> Int {
///        ...
///    }
/// ```
@inlinable public func safe<O: AnyObject>(_ instance: O?) throws -> O {
    guard let instance else {
        throw InstanceError.none
    }
    return instance
}

public enum InstanceError: Error {
    case none
}
