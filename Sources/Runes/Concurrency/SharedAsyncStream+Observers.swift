//
//  SharedAsyncStream+Observers.swift
//  Runes
//
//  Created by Michael Long on 12/29/25.
//

import Foundation

extension SharedAsyncStream {
    ///  Registers a MainActor isolated change observer to observe async events. This can be used as an alternative to for/await streams.
    ///  ```swift
    ///  service.addObserver(self) { [weak self] element in
    ///     self?.value = element.value
    /// }
    /// ```
    /// The observer must be a reference type, as that's used to automatically remove the observer when the observing object goes out of scope.
    ///
    /// The onNext handler will always be called on the MainThread. Use `addNonisolatedObserver` if you don't care about such things.
    @discardableResult
    public func addObserver<O: AnyObject>(_ observer: O, onNext: @escaping @Sendable @MainActor (Element) -> Void) -> UUID {
        addNonisolatedObserver(observer) { element in
            if Thread.isMainThread {
                MainActor.assumeIsolated {
                    onNext(element)
                }
            } else {
                RunLoop.main.perform {
                    MainActor.assumeIsolated {
                        onNext(element)
                    }
                }
            }
        }
    }

    ///  Registers a nonisolated change observer to observe async events. This can be used as an alternative to for/await streams.
    ///  ```swift
    ///  service.addNonisolatedObserver(self) { element in
    ///     print("Observed \(element)")
    /// }
    /// ```
    /// The observer must be a reference type, as that's used to automatically remove the observer when the observing object goes out of scope.
    @discardableResult
    public func addNonisolatedObserver<O: AnyObject>(_ observer: O, onNext: @escaping YieldBlock<Element>) -> UUID {
        let key = UUID()
        _ = addAsyncObserver(key: key, observer: observer, yield: onNext) { [weak self] in
            self?.removeAsyncObserver(key)
        }
        return key
    }

    ///  Removes observer identified by token returned by addObserver.
    ///
    ///  Manual removal isn't normally needed, since addObserver will automatically cleanup when the observing object goes out of scope.
    public func removeObserver(_ key: UUID) {
        removeAsyncObserver(key)
    }
}
