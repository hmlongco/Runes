//
//  SharedAsyncStreamError.swift
//  Runes
//
//  Created by Michael Long on 1/18/26.
//

import Foundation

public extension SharedAsyncStream {
    nonisolated enum SharedAsyncStreamError: Error {
        /// Thrown if task was cancelled
        case cancelled
        /// Invalid state, usually if loading function returns nil for non-nil values
        case invalidLoadingResult
        /// Invalid state, usually if throwing function attempts to return .loading as a result
        case invalidReturnResult
    }
}
