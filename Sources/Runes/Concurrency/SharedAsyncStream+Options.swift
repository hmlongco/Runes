//
//  SharedAsyncStream+Options.swift
//  Runes
//
//  Created by Michael Long on 1/18/26.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

nonisolated public struct SharedAsyncStreamOptions: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    /// Load on first initialization and NOT on first subscription
    nonisolated(unsafe) public static let loadOnInit = SharedAsyncStreamOptions(rawValue: 1 << 0)

#if canImport(UIKit)
    /// Automatically reload values when resuming active from the background
    nonisolated(unsafe) public static let reloadOnActive = SharedAsyncStreamOptions(rawValue: 1 << 1)
#endif

    /// If reload occurs the .loading message will not be sent and subject will remain in the current state
    nonisolated(unsafe) public static let reloadsSilently = SharedAsyncStreamOptions(rawValue: 1 << 2)

    /// If set cancellation errors will terminate value streams
    nonisolated(unsafe) public static let throwsCancellationErrors = SharedAsyncStreamOptions(rawValue: 1 << 3)

    /// Sets global default preferences for AsyncValuesSubjects that don't specify their own.
    ///
    /// Default behavior loads on subscription, doesn't reload on active, sends loading states on reload, and task cancellation doesn't kill
    /// await value observers.
    nonisolated(unsafe) public static var defaults: SharedAsyncStreamOptions = []
}
