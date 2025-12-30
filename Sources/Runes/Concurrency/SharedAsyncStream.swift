//
//  SharedAsyncStream.swift
//  AsyncTrials
//
//  Created by Michael Long on 12/27/25.
//

import Foundation
import os
#if canImport(UIKit)
import UIKit
#endif

/// Shared datasource for async value streams. Stream can be set to automatically load its initial state on first subscription.
/// ```swift
/// class TestService {
///    lazy var integers: SharedAsyncStream<Int> = .init { [weak self] in
///         try await self?.initialLoad()
///    }
///
///    private func initialLoad() async throws -> Int {
///        try await Task.sleep(nanoseconds: 3_000_000_000)
///        return 2
///    }
/// ```
/// Observe that our source definition is lazy. This delays initial loading until the value is accessed and the first subscription or
/// occurs. When used in a class `lazy ` also allows for references to external functions and values.
///
/// Care should be taken in the load function to avoid retain cycles.
///
/// When the load function succeeds the provided value is broadcast to all current subscribers. All new subscribers will see the most recently
/// loaded or sent value.
///
/// If no additional mutable state is required the containing service could also be struct-based and `lazy` omitted. Again, first load only occurs
/// on first subscription.
/// /// ```swift
/// struct TestService {
///    var integers: SharedAsyncStream<Int> = .init {
///         try await initialLoad()
///    }
///
///    private func initialLoad() async throws -> Int {
///        try await Task.sleep(nanoseconds: 3_000_000_000)
///        return 2
///    }
/// ```
/// To consume the shared data as an async stream do:
/// ```swift
/// .task {
///     for await next in viewModel.service.stream {
///         self.value = next.value
///     }
/// }
/// ```
/// Awaiting `service.stream` will trigger the initial loading state, returning `.loading` and then, hopefully, the first value.
///
/// Returned values are of type Element.
/// ```Swift
/// enum Element {
///     case loading
///     case value(Value)
///     case error(Error)
///     case cancelled
/// }
/// ```
/// Element has several helper functions like `value`, `error`, and so on that return optional instances if the type is in fact
/// that particular state.
/// ```swift
/// self.value = next.value // returns value or nil if next isn't a value type
/// ```
/// As mentioned, state can be mutated whenever needed and new values sent to all subscribers/observers.
/// ```Swift
/// extension TestService {
///     func update(value: Int, for id: Int) async throws {
///         let newValue = try await database.update(value, for id: id)
///         service.send(newValue)
///     }
/// }
/// ```
/// Future subscribers will also see the latest value.
///
/// SharedAsyncStream's behavior can be tuned as needed.
/// ```Swift
/// lazy var integers: SharedAsyncStream<Int> = .init(options: [.reloadOnActive, .throwsCancellationErrors]) { [weak self] in
///     try await self?.networking.load()
/// }
/// ```
/// See `SharedAsyncStreamOptions` for more.
nonisolated final public class SharedAsyncStream<Value: Sendable>: @unchecked Sendable {
    public typealias AsyncLoader = () async throws -> Value?

    // MARK: - State (protected by lock)

    private struct AsyncObserver: @unchecked Sendable {
        let observingObject: ObservingObject?
        let yield: @Sendable (Element) -> Void
        let finish: @Sendable () -> Void
    }

    private struct ObservingObject: @unchecked Sendable {
        weak var object: AnyObject?
    }

    private var currentElement: Element
    private var currentToken: Int = 0
    private var currentTask: Task<Void, Never>?
    private var currentTaskToken: Int?
    private var loader: AsyncLoader?
    private var didBecomeActiveObserver: NSObjectProtocol?
    private let options: SharedAsyncStreamOptions
    private var observers: [UUID : AsyncObserver] = [:]
    private let lock = OSAllocatedUnfairLock()

    // MARK: - Init / Deinit

    /// Initialize with value, has no loader
    public init(initialValue: Value) {
        self.currentElement = .value(initialValue)
        self.loader = nil
        self.options = []
    }

    /// Initialize with options and load/reload function.
    public init(options: SharedAsyncStreamOptions = .defaults, loader: @escaping AsyncLoader) {
        self.currentElement = .loading
        self.loader = loader
        self.options = options

        if options.contains(.loadOnInit) {
            triggerLoadIfNeeded(token: currentToken)
        }

#if canImport(UIKit)
        if options.contains(.reloadOnActive) {
            didBecomeActiveObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.reload()
            }
        }
#endif
    }

    deinit {
#if canImport(UIKit)
        if let token = didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(token)
        }
#endif

        currentTask?.cancel()
        finishAllObservers()
    }

    // MARK: - Current value access

    /// Get current stream's Element
    public var current: Element {
        lock.lock(); defer { lock.unlock() }
        return currentElement
    }

    /// Get current stream's value, if any
    public var value: Value? {
        current.value
    }

    /// Get current error state, if any
    public var error: Error? {
        current.error
    }

    // MARK: - Sending states

    /// Cancels current load (if any) and sends value to all observers
    public func send(_ value: Value) {
        cancelCurrentTaskOnly()
        broadcast(.value(value))
    }

    /// Cancels current load (if any) and sends error state to all observers
    public func fail(with error: Error) {
        cancelCurrentTaskOnly()
        broadcast(.error(error))
    }

    /// Explicit cancellation, cancels current tasks AND notifies streams of cancelled loads
    public func cancel() {
        cancelCurrentTaskOnly()
        broadcast(.cancelled)
    }

    // MARK: - Async sequences

    /// Async stream for AsyncValues.
    /// ```swift
    /// .task {
    ///     for await next in viewModel.service.stream {
    ///         self.value = next.value
    ///     }
    /// }
    /// ```
    /// Elements are returned for all cases: .loading, .value, .error, and .cancelled. It's up to the caller to decide
    /// whether or not to exit the for await loop.
    ///
    /// Think of materialize/dematerialize in RxSwift.
    public var stream: AsyncStream<Element> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let token = addAsyncObserver(
                yield: { element in
                    continuation.yield(element)
                },
                finish: {
                    continuation.finish()
                }
            )

            continuation.onTermination = { @Sendable _ in
                self.removeAsyncObserver(token)
            }
        }
    }

    /// Async throwing stream sees values, throws errors
    /// ```swift
    /// .task {
    ///     do {
    ///         for try await value in viewModel.service.values {
    ///             self.value = value
    ///         }
    ///     } catch {
    ///         ???
    ///     }
    /// }
    /// ```
    /// AsyncValue.Value types are returned in the stream. Any .error values cause errors to be thrown and will
    /// exit the stream.
    ///
    /// Cancellation errors may do so if the .throwsCancellationErrors option is set.
    public var values: AsyncThrowingStream<Value?, Error> {
        let throwsCancellationErrors = options.contains(.throwsCancellationErrors)
        return AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let token = addAsyncObserver(
                yield: { element in
                    switch element {
                    case .empty:
                        continuation.yield(nil)
                    case let .value(value):
                        continuation.yield(value)
                    case let .error(error):
                        continuation.finish(throwing: error)
                    case .cancelled:
                        if throwsCancellationErrors {
                            continuation.finish(throwing: CancellationError())
                        }
                    case .loading:
                        break
                    }
                },
                finish: {
                    continuation.finish()
                }
            )

            continuation.onTermination = { @Sendable _ in
                self.removeAsyncObserver(token)
            }
        }
    }

    // MARK: - Helpers

    /// Force a reload via the async loader typically after explicit invalidation.
    ///
    /// Does nothing if loading is currently in progress.
    public func reload() {
        guard lock.withLock { currentTaskToken == nil } == true else {
            return
        }
        if !options.contains(.reloadsSilently) {
            broadcast(.loading)
        }
        triggerLoadIfNeeded(token: lock.withLock { self.currentToken })
    }

    /// external check on loading status
    public var isLoading: Bool {
        lock.withLock { currentTaskToken != nil }
    }

    // MARK: - Internals (observer management)

    internal func addAsyncObserver(
        key: UUID = .init(),
        observer: AnyObject? = nil,
        yield: @escaping @Sendable (Element) -> Void,
        finish: @escaping @Sendable () -> Void,
    ) -> UUID {
        let observingObject: ObservingObject? = observer == nil ? nil : .init(object: observer)

        let (element, token) = lock.withLock {
            self.observers[key] = AsyncObserver(observingObject: observingObject, yield: yield, finish: finish)
            return (currentElement, currentToken)
        }

        yield(element) // always yields current value

        if case .loading = element {
            self.triggerLoadIfNeeded(token: token)
        }

        return key
    }

   internal func removeAsyncObserver(_ key: UUID) {
        lock.withLock {
            observers.removeValue(forKey: key)
        }
    }

    private func broadcast(_ element: Element, token: Int? = nil) {
        // if token has changed then triggerLoadIfNeeded no longer has authority to publish values or errors
        if let token, lock.withLock { self.currentToken != token } == true {
            return
        }

        let (observers, nextToken) = lock.withLock {
            self.currentElement = element
            if token == nil {
                self.currentToken &+= 1
            }
            return (self.observers, self.currentToken)
        }

        for observer in observers {
            if let observingObject = observer.value.observingObject, observingObject.object == nil {
                removeAsyncObserver(observer.key)
            } else {
                observer.value.yield(element)
            }
        }

        if case .loading = element {
            triggerLoadIfNeeded(token: nextToken)
        }
    }

    private func finishAllObservers() {
        let observers = lock.withLock {
            let currentObservers = self.observers
            self.observers.removeAll()
            return currentObservers
        }

        for listener in observers {
            listener.value.finish()
        }
    }

    private func cancelCurrentTaskOnly() {
        let task = lock.withLock {
            defer {
                self.currentTask = nil
                self.currentTaskToken = nil
            }
            return self.currentTask
        }
        task?.cancel()
    }

    /// Conditional internal loading function
    private func triggerLoadIfNeeded(token: Int) {
        lock.withLock {
            guard currentTaskToken == nil else {
                return
            }

            currentTaskToken = token
            currentTask = Task {
                do {
                    try Task.checkCancellation()
                    if let value = try await loader?() {
                        try Task.checkCancellation()
                        broadcast(.value(value), token: token)
                    } else {
                        broadcast(.empty, token: token)
                    }
                } catch is CancellationError {
                    broadcast(.cancelled, token: token)
                } catch {
                    broadcast(.error(error), token: token)
                }

                clearCurrentTask(token: token)
            }
        }
    }

    private func getCurrentToken() -> Int {
        lock.withLock { currentToken }
    }

    private func clearCurrentTask(token: Int) {
        lock.withLock {
            guard currentTaskToken == token else {
                return
            }
            self.currentTask = nil
            self.currentTaskToken = nil
        }
    }
}

public extension SharedAsyncStream {
    /// Status and value type propagated by SharedAsyncStream.
    nonisolated enum Element: @unchecked Sendable {
        case loading
        case empty
        case value(Value)
        case error(Error)
        case cancelled

        /// Returns value from AsyncValue state if it exists
        public var value: Value? {
            if case let .value(value) = self { return value }
            return nil
        }

        public var isValue: Bool {
            if case .value = self { return true }
            return false
        }

        /// Returns error from AsyncValue state if it exists
        public var error: Error? {
            if case let .error(error) = self { return error }
            return nil
        }

        public var isError: Bool {
            if case .error = self { return true }
            return false
        }

        /// Returns true if current AsyncValue state is empty
        public var isEmpty: Bool {
            if case .empty = self { return true }
            return false
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
    }
}

extension SharedAsyncStream.Element: Equatable where Value: Equatable {
    public static func == (lhs: SharedAsyncStream.Element, rhs: SharedAsyncStream.Element) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading): return true
        case let (.value(a), .value(b)): return a == b
        case (.error, .error): return true
        case (.empty, .empty): return true
        case (.cancelled, .cancelled): return true
        default: return false
        }
    }
}

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
