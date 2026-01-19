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
///         try await safe(self).initialLoad()
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
///     for await next in viewModel.service.integers.stream {
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
///         service.integers.send(newValue)
///     }
/// }
/// ```
/// Future subscribers will also see the latest value.
///
/// SharedAsyncStream's behavior can be tuned as needed.
/// ```Swift
/// lazy var integers: SharedAsyncStream<Int> = .init(options: [.reloadOnActive, .throwsCancellationErrors]) { [networking] in
///     try await networking.load()
/// }
/// ```
/// See `SharedAsyncStreamOptions` for more.
nonisolated final public class SharedAsyncStream<Value: Sendable>: @unchecked Sendable {
    public typealias AsyncLoader = () async throws -> Value

    // MARK: - State (protected by lock)

    public typealias YieldBlock<Element> = @Sendable (Element) -> Void
    public typealias FinishBlock = @Sendable () -> Void

    private struct AsyncObserver: @unchecked Sendable {
        let observingObject: ObservingObject?
        let yield: YieldBlock<Element>
        let finish: FinishBlock
    }

    private struct ObservingObject: @unchecked Sendable {
        weak var reference: AnyObject?
    }

    private var currentElement: Element
    private var currentToken: Int = 0
    private var currentTask: Task<Element, Never>?
    private var currentTaskToken: Int?
    private var loader: AsyncLoader?
    private let options: SharedAsyncStreamOptions
    private var observers: [UUID : AsyncObserver] = [:]
    private var onActive: OnNotification?
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
            triggerLoadingTask(token: currentToken)
        }

        if options.contains(.reloadOnActive) {
            #if canImport(UIKit)
            onActive = .didBecomeActive { [weak self] in
                self?.reload()
            }
            #endif
        }
    }

    deinit {
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

    /// Unwrap optional value and return, if any
    public func optionalValue() -> Value.Wrapped? where Value: OptionalProtocol {
        current.optionalValue()
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
    ///     for await next in viewModel.service.integers.stream {
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
    ///         for try await value in viewModel.service.integers.values {
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
    public var values: AsyncThrowingStream<Value, Error> {
        let throwsCancellationErrors = options.contains(.throwsCancellationErrors)
        return AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let token = addAsyncObserver(
                yield: { element in
                    switch element {
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

    // MARK: - Async value access

    /// Returns current value element if present, otherwise triggers load function and awaits result.
    /// ```swift
    /// .task {
    ///     let result = await viewModel.service.integers.asyncElement()
    ///     switch result {
    ///     case let .value(value):
    ///         self.value = value
    ///     default:
    ///         ...
    ///     }
    /// }
    /// ```
    /// Elements are returned for all cases: .loading, .value, .error, and .cancelled.
    ///
    /// Will also broadcast results to any subscribers or streams.
    public func asyncElement(forceReload: Bool = false) async -> Element {
        if forceReload == false, case .value(let value) = current {
            return .value(value)
        }
        let task = lock.withLock {
            triggerLoadingTask(token: currentToken)
        }
        return try await task.value
    }

    /// Returns current value if present, otherwise triggers load function and awaits result.
    /// ```swift
    /// .task {
    ///     do {
    ///         self.value = try await viewModel.service.integers.asyncValue()
    ///     } catch {
    ///         ???
    ///     }
    /// }
    /// ```
    /// Will also broadcast results to any subscribers or streams.
    public func asyncValue(forceReload: Bool = false) async throws -> Value {
        try await asyncElement(forceReload: forceReload).throwingValue()
    }

    // MARK: - Helpers

    /// Force a reload via the async loader typically after explicit invalidation.
    ///
    /// Does nothing if loading is currently in progress.
    public func reload() {
        guard let token: Int = lock.withLock({ currentTaskToken == nil ? currentToken : nil }) else {
            return
        }
        if !options.contains(.reloadsSilently) {
            broadcast(.loading)
        }
        triggerLoadingTask(token: token)
    }

    /// external check on loading status
    public var isLoading: Bool {
        lock.withLock { currentTaskToken != nil }
    }

    // MARK: - Internals (observer management)

    internal func addAsyncObserver(
        key: UUID = .init(),
        observer: AnyObject? = nil,
        yield: @escaping YieldBlock<Element>,
        finish: @escaping FinishBlock,
    ) -> UUID {
        let object: ObservingObject? = observer == nil ? nil : .init(reference: observer)

        let (element, token) = lock.withLock {
            self.observers[key] = AsyncObserver(observingObject: object, yield: yield, finish: finish)
            return (currentElement, currentToken)
        }

        Task {
            guard token == self.getCurrentToken() else {
                return
            }
            
            yield(element)

            if case .loading = element {
                self.triggerLoadingTask(token: token)
            }
        }

        return key
    }

   internal func removeAsyncObserver(_ key: UUID) {
        lock.withLock {
            observers.removeValue(forKey: key)
        }
    }

    private func broadcast(_ element: Element, token: Int? = nil) {
        guard let (observers, nextToken): ([UUID : AsyncObserver], Int) = lock.withLock({
            // if token has changed then triggerLoadIfNeeded no longer has authority to publish values or errors
            if let token, self.currentToken != token {
                return nil
            }
            self.currentElement = element
            self.currentToken &+= 1
            return (self.observers, self.currentToken)
        }) else {
            return
        }

        for observer in observers {
            if let observingObject = observer.value.observingObject, observingObject.reference == nil {
                removeAsyncObserver(observer.key)
            } else {
                observer.value.yield(element)
            }
        }

        if case .loading = element {
            triggerLoadingTask(token: nextToken)
        }
    }

    private func finishAllObservers() {
        let observers = lock.withLock {
            defer { self.observers.removeAll() }
            return self.observers
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
    @discardableResult
    private func triggerLoadingTask(token: Int) -> Task<Element, Never> {
        lock.withLock {
            if currentTaskToken != nil, let currentTask {
                return currentTask
            }

            currentTaskToken = token
            let task = Task {
                let element = await asyncLoad()
                broadcast(element, token: token)
                clearCurrentTask(token: token)
                return element
            }
            currentTask = task
            return task
        }
    }

    /// Call load function, breaking results down into Element
    private func asyncLoad() async -> Element {
        do {
            try Task.checkCancellation()
            if let loader {
                let value = try await loader()
                try Task.checkCancellation()
                return .value(value)
            } else {
                return .error(SharedAsyncStreamError.invalidInstance)
            }
        } catch is CancellationError {
            return .cancelled
        } catch is InstanceError {
            return .error(SharedAsyncStreamError.invalidInstance)
        } catch {
            return .error(error)
        }
    }

    private func getCurrentToken() -> Int {
        lock.withLock { currentToken }
    }

    private func clearCurrentTask(token: Int) {
        lock.withLock {
            if currentTaskToken == token {
                self.currentTask = nil
                self.currentTaskToken = nil
            }
        }
    }
}
