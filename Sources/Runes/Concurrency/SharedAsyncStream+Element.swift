//
//  Element.swift
//  Runes
//
//  Created by Michael Long on 1/18/26.
//


public extension SharedAsyncStream {
    /// Status and value type propagated by SharedAsyncStream.
    nonisolated enum Element: @unchecked Sendable {
        case loading
        case value(Value)
        case error(Error)
        case cancelled

        /// Returns value from AsyncValue state if it exists
        public var value: Value? {
            if case let .value(value) = self { return value }
            return nil
        }

        /// Unwraps optional type. Use instead of `value` if `Value` is optional. (e.g. `SharedAsyncStream<Int?>` }
        ///
        /// Returns nil if the element was not a value, and returns nil if the we had a value, but the optional value was nil.
        public func optionalValue() -> Value.Wrapped? where Value: OptionalProtocol {
            if case let .value(value) = self {
                return value.wrappedValue
            }
            return nil
        }

        /// Return true if element has a value
        public var isValue: Bool {
            if case .value = self { return true }
            return false
        }

        /// Returns error from AsyncValue state if it exists. Includes cancellation errors.
        public var error: Error? {
            if case let .error(error) = self {
                return error
            }
            if case let .cancelled = self {
                return SharedAsyncStreamError.cancelled
            }
            return nil
        }

        /// Returns true if error or cancellation error
        public var isError: Bool {
            return error != nil
        }

        /// Returns true if current AsyncValue state is loading
        public var isLoading: Bool {
            if case .loading = self { return true }
            return false
        }

        /// Returns true if current AsyncValue state is cancelled
        public var isCancelled: Bool {
            if case .cancelled = self { return true }
            return false
        }

        /// Returns value or throws error
        public func throwingValue() throws -> Value {
            switch self {
            case let .value(value):
                return value
            case .loading:
                throw SharedAsyncStreamError.invalidReturnResult
            case let .error(error):
                throw error
            case .cancelled:
                throw SharedAsyncStreamError.cancelled
            }
        }
    }
}

extension SharedAsyncStream.Element: Equatable where Value: Equatable {
    public static func == (lhs: SharedAsyncStream.Element, rhs: SharedAsyncStream.Element) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading): return true
        case let (.value(a), .value(b)): return a == b
        case (.error, .error): return true
        case (.cancelled, .cancelled): return true
        default: return false
        }
    }
}
