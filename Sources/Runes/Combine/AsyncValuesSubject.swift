//
//  AsyncValuesSubject.swift
//  Runes
//
//  Created by Michael Long on 12/20/25.
//

@preconcurrency import Combine
@preconcurrency import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Shared datasource for async value streams. Subject automatically loads its initial state on first subscription.
/// ```swift
/// class TestService {
///    lazy var integers: AsyncValuesSubject<Int> = .init { [weak self] in
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
/// ```swift
/// struct TestService {
///    var integers: AsyncValuesSubject<Int> = .init {
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
/// One can also use the Combine publisher directly.
/// ```swift
/// .onReceive(viewModel.service.publisher) { next in
///     self.value = next.value
/// }
/// ```
/// Returned values are of the enumerated type Element.
/// ```swift
/// enum Element {
///     case loading
///     case value(Value)
///     case error(Error)
///     case cancelled
/// }
/// ```
/// Element, as shown above, has several helper functions like `value`, `error`, and so on that return optional instances if the type is in fact
/// that particular state.
/// ```swift
/// self.value = next.value // returns value or nil if next isn't a value type
/// ```
/// As mentioned, state can be mutated whenever needed and new values sent to all subscribers/listeners.
/// ```swift
/// extension TestService {
///     func update(value: Int, for id: Int) async throws {
///         let newValue = try await database.update(value, for id: id)
///         service.send(newValue)
///     }
/// }
/// ```
/// Future subscribers will also see the latest value.
///
/// AsyncValuesSubject's behavior can be tuned as needed.
/// ```Swift
/// lazy var integers: AsyncValuesSubject<Int> = .init(options: [.reloadOnActive, .throwsCancellationErrors]) { [weak self] in
///     try await self?.networking.load()
/// }
/// ```
/// See `AsyncValuesSubjectOptions` for more.
final public class AsyncValuesSubject<Value: Sendable>: @unchecked Sendable {
    public typealias AsyncLoader = () async throws -> Value?

    private let subject: CurrentValueSubject<Element, Never>
    private let options: AsyncValuesSubjectOptions
    private var loader: AsyncLoader?
    private var currentTask: Task<Void, Never>?
    private var didBecomeActiveObserver: NSObjectProtocol?

    /// Initialize with value, has no loader
    public init(initialValue: Value) {
        self.subject = .init(.value(initialValue))
        self.loader = nil
        self.options = []
    }

    /// Initialize with options and load/reload function.
    public init(options: AsyncValuesSubjectOptions = .defaults, loader: @escaping AsyncLoader) {
        self.subject = .init(.loading)
        self.loader = loader
        self.options = options

        if options.contains(.loadOnInit) {
            triggerLoadIfNeeded()
        }

        #if canImport(UIKit)
        if options.contains(.reloadOnActive) {
            didBecomeActiveObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.reload()
                }
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
        currentTask = nil
        subject.send(.cancelled)
        subject.send(completion: .finished)
    }

    /// Get current subject's Element
    public var current: Element {
        subject.value
    }

    /// Get current subject's value, if any
    public var value: Value? {
        subject.value.value
    }

    // Get current error state, if any
    public var error: Error? {
        subject.value.error
    }

    /// Cancels current load (if any) and sends value to all listeners
    public func send(_ value: Value) {
        currentTask?.cancel()
        currentTask = nil
        subject.send(.value(value))
    }

    /// Cancels current load (if any) and sends error state to all listeners
    public func fail(with error: Error) {
        currentTask?.cancel()
        currentTask = nil
        subject.send(.error(error))
    }

    /// Combine publisher for AsyncValues.
    /// ```swift
    /// .onReceive(viewModel.service.publisher) { next in
    ///     self.value = next.value
    /// }
    /// ```
    /// This also contains the core "load on first subscription" function on which the async streams functions are built.
    ///
    /// Elements are returned for all cases: .loading, .value, .error, and .cancelled. It's up to the caller to decide
    /// how to handle the cases and associated values.
    ///
    /// Think of materialize/dematerialize in RxSwift.
   public var publisher: AnyPublisher<Element, Never> {
        subject
            .map { [weak self] next in
                if case .loading = next {
                    self?.triggerLoadIfNeeded()
                }
                return next
            }
            .eraseToAnyPublisher()
    }

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
            let cancellable = publisher
                .sink { completion in
                    continuation.finish()
                } receiveValue: { next in
                    continuation.yield(next)
                }

            continuation.onTermination = { @Sendable _ in
                cancellable.cancel()
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
    /// AsyncValue.Value types are returned in the stream. Published .error values cause errors to be thrown and will
    /// exit the stream.
    ///
    /// Cancellation errors may do so if the .throwsCancellationErrors option is set.
    public var values: AsyncThrowingStream<Value?, Error> {
        let throwsCancellationErrors = options.contains(.throwsCancellationErrors)
        return AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let cancellable = publisher
                .sink { completion in
                    continuation.finish()
                } receiveValue: { next in
                    switch next {
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
                }

            continuation.onTermination = { @Sendable _ in
                cancellable.cancel()
            }
        }
    }

    /// Force a reload via the async loader typically after explicit invalidation.
    ///
    /// Does nothing if loading is currently in progress.
    public func reload() {
        if !options.contains(.reloadsSilently) {
            subject.send(.loading)
        }
        triggerLoadIfNeeded()
    }

    /// Explicit cancellation, cancels current tasks AND notifies streams of cancelled loads
    public func cancel() {
        currentTask?.cancel()
        currentTask = nil
        subject.send(.cancelled)
    }

    /// Internal loading function
    private func triggerLoadIfNeeded() {
        guard let loader, currentTask == nil else {
            return
        }

        currentTask = Task { @MainActor [weak self] in
            defer {
                self?.currentTask = nil
            }

            do {
                try Task.checkCancellation()
                if let value = try await loader() {
                    try Task.checkCancellation()
                    self?.subject.send(.value(value))
                } else {
                    self?.subject.send(.empty)
                }
            } catch is CancellationError {
                self?.subject.send(.cancelled)
            } catch {
                self?.subject.send(.error(error))
            }
        }
    }
}

public extension AsyncValuesSubject {
    /// Status and value type propagated by AsyncValuesSubject.
    enum Element: @unchecked Sendable {
        case loading
        case empty
        case value(Value)
        case error(Error)
        case cancelled

        /// Returns value from AsyncValue state if it exists
        public var value: Value? {
            if case let .value(value) = self {
                return value
            }
            return nil
        }

        /// Returns error from AsyncValue state if it exists
        public var error: Error? {
            if case let .error(error) = self {
                return error
            }
            return nil
        }

        /// Returns true if current AsyncValue state is empty
        public var isEmpty: Bool {
            if case .empty = self {
                return true
            }
            return false
        }

        /// Returns true if current AsyncValue state is loading
        public var isLoading: Bool {
            if case .loading = self {
                return true
            }
            return false
        }

        /// Returns true if current AsyncValue state is cancelled
        public var isCancelled: Bool {
            if case .cancelled = self {
                return true
            }
            return false
        }
    }
}

extension AsyncValuesSubject.Element: Equatable where Value: Equatable {
    public static func == (lhs: AsyncValuesSubject.Element, rhs: AsyncValuesSubject.Element) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading):
            return true
        case let (.value(lhsValue), .value(rhsValue)):
            return lhsValue == rhsValue
        case (.error, .error):
            return true
        case (.empty, .empty):
            return true
        case (.cancelled, .cancelled):
            return true
        default:
            return false
        }
    }
}

public struct AsyncValuesSubjectOptions: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Load on first initialization and NOT on first subscription
    public static let loadOnInit = AsyncValuesSubjectOptions(rawValue: 1 << 0)

    #if canImport(UIKit)
    /// Automatically reload values when resuming active from the background
    public static let reloadOnActive = AsyncValuesSubjectOptions(rawValue: 1 << 1)
    #endif

    /// If reload occurs the .loading message will not be sent and subject will remain in the current state
    public static let reloadsSilently = AsyncValuesSubjectOptions(rawValue: 1 << 2)

    /// If set cancellation errors will terminate value streams
    public static let throwsCancellationErrors = AsyncValuesSubjectOptions(rawValue: 1 << 3)

    /// Sets global default preferences for AsyncValuesSubjects that don't specify their own.
    ///
    /// Default behavior loads on subscription, doesn't reload on active, sends loading states on reload, and task cancellation doesn't kill
    /// await value listeners.
    nonisolated(unsafe) public static var defaults: AsyncValuesSubjectOptions = []
}
